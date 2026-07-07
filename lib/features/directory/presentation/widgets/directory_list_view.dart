import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../invoices/domain/models/invoice_model.dart';
import 'directory_detail_sheet.dart';

class DirectoryEntity {
  final String name;
  final List<InvoiceModel> invoices;

  DirectoryEntity({required this.name, required this.invoices});

  double get totalSpend => invoices.fold(0, (sum, inv) => sum + inv.amount);
  int get activeInvoices => invoices.where((i) => i.status == 'pending_approval' || i.status == 'pending_payment').length;
}

final directoryProvider = FutureProvider.family<List<DirectoryEntity>, String>((ref, type) async {
  final response = await Supabase.instance.client
      .from('invoices')
      .select()
      .eq('invoice_type', type)
      .order('created_at', ascending: false);

  final rawInvoices = (response as List).map((e) => InvoiceModel.fromJson(e)).toList();
  
  final Map<String, List<InvoiceModel>> grouped = {};
  for (var inv in rawInvoices) {
    if (!grouped.containsKey(inv.vendorName)) {
      grouped[inv.vendorName] = [];
    }
    grouped[inv.vendorName]!.add(inv);
  }

  return grouped.entries.map((e) => DirectoryEntity(name: e.key, invoices: e.value)).toList();
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

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (entities) {
        if (entities.isEmpty) {
          return const Center(child: Text('No records found.'));
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
                subtitle: Text('${entity.activeInvoices} Active Invoices'),
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
