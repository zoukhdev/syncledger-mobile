import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/document_workspace.dart';
import '../widgets/invoice_form_dialog.dart';
import '../widgets/status_badge.dart';
import '../../domain/models/invoice_model.dart';
import '../../utils/pdf_generator.dart';
import '../../../auth/providers/auth_provider.dart';

final invoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final connectivity = await Connectivity().checkConnectivity();
  
  if (connectivity.contains(ConnectivityResult.none)) {
    // Offline Mode: Load from cache
    final cachedData = prefs.getString('cached_invoices');
    if (cachedData != null) {
      final List decoded = jsonDecode(cachedData);
      return decoded.map((e) => InvoiceModel.fromJson(e)).toList();
    }
    return []; // No cache available
  }

  // Online Mode: Fetch from Supabase and cache
  final response = await Supabase.instance.client
      .from('invoices')
      .select()
      .order('created_at', ascending: false);
      
  await prefs.setString('cached_invoices', jsonEncode(response));
  return (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
});

// Removed userRoleProvider to use authProvider instead

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  InvoiceModel? _selectedInvoice;
  String _activeTab = 'approval';
  
  late final Map<ShortcutActivator, Intent> _shortcuts;
  late final Map<Type, Action<Intent>> _actions;

  @override
  void initState() {
    super.initState();
    _shortcuts = {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewInvoiceIntent(),
      LogicalKeySet(LogicalKeyboardKey.escape): const CloseWorkspaceIntent(),
    };
    _actions = {
      NewInvoiceIntent: CallbackAction<NewInvoiceIntent>(
        onInvoke: (intent) => _openInvoiceDialog(),
      ),
      CloseWorkspaceIntent: CallbackAction<CloseWorkspaceIntent>(
        onInvoke: (intent) => setState(() => _selectedInvoice = null),
      ),
    };
  }

  void _openInvoiceDialog([InvoiceModel? invoice]) {
    showDialog(
      context: context,
      builder: (context) => InvoiceFormDialog(invoice: invoice),
    ).then((_) {
      ref.refresh(invoicesProvider);
    });
  }

  Future<void> _deleteInvoice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('invoices').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
          ref.refresh(invoicesProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final role = ref.watch(authProvider).value?.role ?? 'staff';

    return FocusableActionDetector(
      shortcuts: _shortcuts,
      actions: _actions,
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ledger'),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New Invoice (Ctrl+N)'),
              onPressed: _openInvoiceDialog,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: invoicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (allInvoices) {
            final invoices = allInvoices.where((inv) {
              if (_activeTab == 'approval') return inv.status == 'pending_approval';
              if (_activeTab == 'payment') return inv.status == 'pending_payment' || inv.status == 'approved';
              if (_activeTab == 'returned') return inv.status == 'pending_review';
              if (_activeTab == 'completed') return inv.status == 'paid';
              if (_activeTab == 'rejected') return inv.status == 'flagged_rejected';
              return true;
            }).toList();

            Widget buildChip(String label, String value) {
              final isSelected = _activeTab == value;
              final theme = Theme.of(context);
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (val) => setState(() { _activeTab = value; _selectedInvoice = null; }),
                selectedColor: theme.colorScheme.primary,
                checkmarkColor: theme.colorScheme.onPrimary,
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      buildChip('Pending Approval', 'approval'),
                      const SizedBox(width: 8),
                      buildChip('Pending Payment', 'payment'),
                      const SizedBox(width: 8),
                      buildChip('Returned', 'returned'),
                      const SizedBox(width: 8),
                      buildChip('Completed', 'completed'),
                      const SizedBox(width: 8),
                      buildChip('Rejected', 'rejected'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Card(
                    margin: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              // Mobile View
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: invoices.length,
                                itemBuilder: (context, index) {
                                  final invoice = invoices[index];
                                  return Dismissible(
                                    key: Key(invoice.id),
                                    background: Container(
                                      color: Colors.green,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(Icons.check, color: Colors.white),
                                    ),
                                    secondaryBackground: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(Icons.close, color: Colors.white),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (role != 'owner' && role != 'accountant') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Not authorized to approve/reject invoices')),
                                        );
                                        return false;
                                      }
                                      
                                      final newStatus = direction == DismissDirection.startToEnd ? 'approved' : 'flagged_rejected';
                                      
                                      try {
                                        await Supabase.instance.client
                                            .from('invoices')
                                            .update({'status': newStatus})
                                            .eq('id', invoice.id);
                                        
                                        ref.invalidate(invoicesProvider);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Invoice $newStatus')),
                                        );
                                        return true; // Remove from list momentarily until refresh
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                        return false;
                                      }
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                                      child: ListTile(
                                        onTap: () => _showWorkspaceDialog(invoice),
                                        title: Text(invoice.vendorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${invoice.date.day}/${invoice.date.month}/${invoice.date.year}"),
                                            const SizedBox(height: 4),
                                            StatusBadge(status: invoice.status),
                                          ],
                                        ),
                                        trailing: Text("${invoice.amount.toStringAsFixed(2)} DZD", 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                            // Desktop View
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Client / Vendor')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: invoices.map((invoice) {
                                  return DataRow(
                                    onSelectChanged: (selected) {
                                      if (selected == true) {
                                        _showWorkspaceDialog(invoice);
                                      }
                                    },
                                    cells: [
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: invoice.invoiceType == 'receivable' ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            invoice.invoiceType == 'receivable' ? 'Client' : 'Vendor',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: invoice.invoiceType == 'receivable' ? Colors.blue : Colors.grey,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        )
                                      ),
                                      DataCell(Text(invoice.vendorName)),
                                      DataCell(Text("${invoice.date.day}/${invoice.date.month}/${invoice.date.year}")),
                                      DataCell(Text("${invoice.amount.toStringAsFixed(2)} DZD", style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(StatusBadge(status: invoice.status)),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              onTap: () => PdfGenerator.generateAndShareInvoice(invoice),
                                              child: const Text('Export PDF'),
                                            ),
                                            if (role == 'owner' || role == 'accountant')
                                              PopupMenuItem(
                                                onTap: () => _openInvoiceDialog(invoice),
                                                child: const Text('Edit'),
                                              ),
                                            if (role == 'owner')
                                              PopupMenuItem(
                                                onTap: () => _deleteInvoice(invoice.id),
                                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
          },
        ),
      ),
    );
  }

  void _showWorkspaceDialog(InvoiceModel invoice) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          child: DocumentWorkspace(
            invoice: invoice,
            onClose: () {
              Navigator.of(context).pop();
              ref.invalidate(invoicesProvider);
            },
          ),
        ),
      ),
    );
  }
}

class NewInvoiceIntent extends Intent {
  const NewInvoiceIntent();
}

class CloseWorkspaceIntent extends Intent {
  const CloseWorkspaceIntent();
}
