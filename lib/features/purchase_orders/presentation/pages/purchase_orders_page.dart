import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_orders_provider.dart';

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
      ),
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (pos) {
          if (pos.isEmpty) {
            return const Center(child: Text('No purchase orders found.'));
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
          // TODO: Open Create PO Dialog
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
