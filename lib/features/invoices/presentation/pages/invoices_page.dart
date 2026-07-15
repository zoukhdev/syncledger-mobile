import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Widget _buildFilterChip(String label, String value, {bool isSelected = false, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (val) => setState(() { _activeTab = value; _selectedInvoice = null; }),
        backgroundColor: color ?? Colors.white,
        selectedColor: color ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade200),
        ),
        showCheckmark: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final role = ref.watch(authProvider).value?.role ?? 'staff';
    final l10n = AppLocalizations.of(context);

    return FocusableActionDetector(
      shortcuts: _shortcuts,
      actions: _actions,
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
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

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(l10n?.newInvoice ?? 'New Invoice', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052CC),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: _openInvoiceDialog,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n?.search ?? 'Search invoices',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchQuery.isNotEmpty 
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey), 
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  }
                                ) 
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        _buildFilterChip(l10n?.pendingApproval ?? 'Pending Approval', 'approval', isSelected: _activeTab == 'approval', color: const Color(0xFFFFEBD2)),
                        _buildFilterChip(l10n?.pendingPayment ?? 'Pending Payment', 'payment', isSelected: _activeTab == 'payment', color: const Color(0xFFE0F2FE)), // Light blue
                        _buildFilterChip(l10n?.returned ?? 'Returned', 'returned', isSelected: _activeTab == 'returned', color: const Color(0xFFFEF3C7)), // Light yellow
                        _buildFilterChip(l10n?.completed ?? 'Paid', 'completed', isSelected: _activeTab == 'completed', color: const Color(0xFFD4F3E2)),
                        _buildFilterChip(l10n?.rejected ?? 'Overdue', 'rejected', isSelected: _activeTab == 'rejected', color: const Color(0xFFFFD6D6)),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: LayoutBuilder(
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
                              child: GestureDetector(
                                onTap: () => _showWorkspaceDialog(invoice),
                                child: InvoiceCard(
                                  clientName: invoice.vendorName,
                                  date: "${invoice.date.day}/${invoice.date.month}/${invoice.date.year}",
                                  amount: invoice.amount.toStringAsFixed(2),
                                  status: invoice.status,
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

class InvoiceCard extends StatelessWidget {
  final String clientName;
  final String date;
  final String amount;
  final String status;

  const InvoiceCard({
    super.key,
    required this.clientName,
    required this.date,
    required this.amount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    
    // Map backend status to UI color
    Color badgeColor = const Color(0xFFFFF4E5); // Default Soft Orange
    Color textColor = const Color(0xFFB45309); // Default Dark Orange
    String displayStatus = status.replaceAll('_', ' ').toUpperCase();
    
    if (status == 'paid') {
      badgeColor = const Color(0xFFD4F3E2);
      textColor = const Color(0xFF065F46);
    } else if (status == 'flagged_rejected') {
      badgeColor = const Color(0xFFFFD6D6);
      textColor = const Color(0xFF991B1B);
    } else if (status == 'approved' || status == 'pending_payment') {
      badgeColor = const Color(0xFFE0F2FE);
      textColor = const Color(0xFF075985);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "$amount DZD",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0052CC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
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
