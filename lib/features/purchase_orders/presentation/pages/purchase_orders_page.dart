import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/purchase_orders_provider.dart';
import '../widgets/new_purchase_order_dialog.dart';
import '../../../../domain/models/purchase_order_model.dart';

class PurchaseOrdersPage extends ConsumerWidget {
  const PurchaseOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(purchaseOrdersProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        leading: BackButton(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          l10n.purchaseOrders,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search Purchase Orders',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: posAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('${l10n.errorPrefix(err.toString())}')),
              data: (pos) {
                if (pos.isEmpty) {
                  return Center(child: Text(l10n.noPurchaseOrders));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: pos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final po = pos[index];
                    return PurchaseOrderCard(
                      po: po,
                      onTap: () {
                        context.push('/purchase-orders/${po.id}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF283556), // Deep navy
        shape: const CircleBorder(),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewPurchaseOrderDialog(),
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class PurchaseOrderCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final VoidCallback onTap;

  const PurchaseOrderCard({super.key, required this.po, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color badgeBgColor = const Color(0xFFE2E8F0);
    Color badgeTextColor = const Color(0xFF475569);
    
    if (po.status.toLowerCase() == 'pending') {
      badgeBgColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
    } else if (po.status.toLowerCase() == 'approved') {
      badgeBgColor = const Color(0xFFD1FAE5);
      badgeTextColor = const Color(0xFF059669);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  po.poNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    po.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Vendor A', // TODO: We need vendor name from join, using hardcoded/empty if not present on model
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${po.totalAmount.toStringAsFixed(2)} DZD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0052CC), // Brand Blue
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
