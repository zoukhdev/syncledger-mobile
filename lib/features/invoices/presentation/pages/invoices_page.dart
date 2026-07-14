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
import '../../../../core/localization/locale_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final invoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  const secureStorage = FlutterSecureStorage();
  final connectivity = await Connectivity().checkConnectivity();
  
  if (connectivity.contains(ConnectivityResult.none)) {
    // Offline Mode: Load from secure cache
    final cachedData = await secureStorage.read(key: 'cached_invoices');
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
      
  await secureStorage.write(key: 'cached_invoices', value: jsonEncode(response));
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
  String _pdfLang = 'fr';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _dateRange;
  
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
        title: Text(AppLocalizations.of(context)?.deleteInvoice ?? 'Delete Invoice'),
        content: Text(AppLocalizations.of(context)?.deleteConfirm ?? 'Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete')
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
          title: Text(AppLocalizations.of(context)?.ledger ?? 'Ledger'),
          actions: [
            ElevatedButton.icon(
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
              label: Text(AppLocalizations.of(context)?.newInvoice ?? 'New Invoice'),
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
              bool matchesTab = true;
              if (_activeTab == 'approval') matchesTab = inv.status == 'pending_approval';
              else if (_activeTab == 'payment') matchesTab = inv.status == 'pending_payment' || inv.status == 'approved';
              else if (_activeTab == 'returned') matchesTab = inv.status == 'pending_review';
              else if (_activeTab == 'completed') matchesTab = inv.status == 'paid';
              else if (_activeTab == 'rejected') matchesTab = inv.status == 'flagged_rejected';

              if (!matchesTab) return false;

              if (_searchQuery.isNotEmpty) {
                if (!inv.vendorName.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return false;
                }
              }

              if (_dateRange != null) {
                if (inv.date.isBefore(_dateRange!.start) || inv.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
                  return false;
                }
              }

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)?.search ?? 'Search by vendor...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear), 
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    }
                                  ) 
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.date_range, color: _dateRange != null ? Theme.of(context).colorScheme.primary : null),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _dateRange,
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                          } else if (_dateRange != null) {
                            // Cancelled, clear the filter if they click outside? 
                            // Actually, let's keep it. 
                            // To clear, they can click a "Clear" button that we could add.
                            // But a long press could clear it. Let's just clear it if picked == null for simplicity.
                            setState(() => _dateRange = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      buildChip(AppLocalizations.of(context)?.pendingApproval ?? 'Pending Approval', 'approval'),
                      const SizedBox(width: 8),
                      buildChip(AppLocalizations.of(context)?.pendingPayment ?? 'Pending Payment', 'payment'),
                      const SizedBox(width: 8),
                      buildChip(AppLocalizations.of(context)?.returned ?? 'Returned', 'returned'),
                      const SizedBox(width: 8),
                      buildChip(AppLocalizations.of(context)?.completed ?? 'Completed', 'completed'),
                      const SizedBox(width: 8),
                      buildChip(AppLocalizations.of(context)?.rejected ?? 'Rejected', 'rejected'),
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
                                columns: [
                                  DataColumn(label: Text(AppLocalizations.of(context)?.type ?? 'Type')),
                                  DataColumn(label: Text(AppLocalizations.of(context)?.clientVendor ?? 'Client / Vendor')),
                                  DataColumn(label: Text(AppLocalizations.of(context)?.date ?? 'Date')),
                                  DataColumn(label: Text(AppLocalizations.of(context)?.amount ?? 'Amount')),
                                  DataColumn(label: Text(AppLocalizations.of(context)?.status ?? 'Status')),
                                  DataColumn(label: Text(AppLocalizations.of(context)?.actions ?? 'Actions')),
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
                                            invoice.invoiceType == 'receivable' ? (AppLocalizations.of(context)?.client ?? 'Client') : (AppLocalizations.of(context)?.vendor ?? 'Vendor'),
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
                                              onTap: () {
                                                final lang = ref.read(localeProvider).languageCode;
                                                PdfGenerator.generateAndShareInvoice(invoice, lang: lang);
                                              },
                                              child: Text(AppLocalizations.of(context)?.exportPdf ?? 'Export PDF'),
                                            ),
                                            if (role == 'owner' || role == 'accountant')
                                              PopupMenuItem(
                                                onTap: () => _openInvoiceDialog(invoice),
                                                child: Text(AppLocalizations.of(context)?.edit ?? 'Edit'),
                                              ),
                                            if (role == 'owner')
                                              PopupMenuItem(
                                                onTap: () => _deleteInvoice(invoice.id),
                                                child: Text(AppLocalizations.of(context)?.delete ?? 'Delete', style: const TextStyle(color: Colors.red)),
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
