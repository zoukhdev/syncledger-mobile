import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../invoices/domain/models/invoice_model.dart';
import 'directory_detail_sheet.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DirectoryEntity {
  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final List<InvoiceModel> invoices;

  DirectoryEntity({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    required this.invoices,
  });

  double get totalSpend => invoices.fold(0, (sum, inv) => sum + inv.amount);
  int get activeInvoices => invoices.where((i) => i.status == 'pending_approval' || i.status == 'pending_payment').length;
}

final directoryProvider = FutureProvider.family<List<DirectoryEntity>, String>((ref, type) async {
  final contractorsResponse = await Supabase.instance.client
      .from('contractors')
      .select('*, invoices(*)')
      .order('created_at', ascending: false);

  final rawContractors = contractorsResponse as List;
  
  final List<DirectoryEntity> entities = [];
  
  for (var contractor in rawContractors) {
    final rawInvoices = contractor['invoices'] as List? ?? [];
    final allInvoices = rawInvoices.map((e) => InvoiceModel.fromJson(e)).toList();
    
    // Filter invoices by type (receivable for clients, payable for vendors)
    final typedInvoices = allInvoices.where((inv) => inv.invoiceType == type).toList();
    
    entities.add(DirectoryEntity(
      id: contractor['id'],
      name: contractor['company_name'],
      contactName: contractor['contact_name'],
      email: contractor['email'],
      phone: contractor['phone'],
      invoices: typedInvoices,
    ));
  }
  
  // Sort by total spend descending
  entities.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));

  return entities;
});

class DirectoryListView extends ConsumerWidget {
  final String type; // 'receivable' for clients, 'payable' for vendors
  const DirectoryListView({super.key, required this.type});

  void _showDetails(BuildContext context, DirectoryEntity entity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DirectoryDetailSheet(entity: entity),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(directoryProvider(type));
    final t = AppLocalizations.of(context);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(t?.errorPrefix(err.toString()) ?? 'Error: $err')),
      data: (entities) {
        if (entities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(t?.noVendors ?? 'No records found.', style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(t?.noVendorsDesc ?? "You haven't added any records yet.", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entities.length,
          itemBuilder: (context, index) {
            final entity = entities[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                title: Text(entity.name, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text('${entity.activeInvoices} ${t?.active ?? 'Active'}'),
                trailing: Text(
                  '${entity.totalSpend.toStringAsFixed(2)} DZD',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onTap: () => _showDetails(context, entity),
              ),
            );
          },
        );
      },
    );
  }
}
