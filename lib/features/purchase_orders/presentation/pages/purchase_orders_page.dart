import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/purchase_orders_provider.dart';
import '../widgets/new_purchase_order_dialog.dart';

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(purchaseOrdersProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseOrders),
      ),
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${l10n.errorPrefix(err.toString())}')),
        data: (pos) {
          if (pos.isEmpty) {
            return Center(child: Text(l10n.noPurchaseOrders));
          }
          return ListView.builder(
            itemCount: pos.length,
            itemBuilder: (context, index) {
              final po = pos[index];
              return ListTile(
                title: Text(po.poNumber),
                subtitle: Text('Total: ${po.totalAmount.toStringAsFixed(2)} DA'),
                trailing: Chip(label: Text(po.status)),
                onTap: () {
                  // TODO: Navigate to PO detail
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewPurchaseOrderDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
