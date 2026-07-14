import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/purchase_orders_provider.dart';
import '../../utils/po_pdf_generator.dart';

class PurchaseOrderDetailPage extends ConsumerWidget {
  final String poId;
  const PurchaseOrderDetailPage({super.key, required this.poId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseOrderDetailProvider(poId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Order Details'),
        actions: [
          detailAsync.maybeWhen(
            data: (detail) => IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => POPdfGenerator.generateAndSharePO(detail),
              tooltip: 'Generate PDF',
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading PO details: $err')),
        data: (detail) {
          final po = detail.po;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PO #${po.poNumber}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(po.status.toUpperCase()),
                              backgroundColor: Colors.blueGrey.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Vendor:', detail.vendorName ?? 'N/A'),
                        if (po.issuedAt != null) _buildDetailRow('Issue Date:', DateFormat('yyyy-MM-dd').format(po.issuedAt!)),
                        if (po.expectedDelivery != null) _buildDetailRow('Expected Delivery:', DateFormat('yyyy-MM-dd').format(po.expectedDelivery!)),
                        _buildDetailRow('Total Amount:', '${po.totalAmount.toStringAsFixed(2)} DZD'),
                        if (po.notes != null && po.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(po.notes!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Line Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: detail.lineItems.length,
                  itemBuilder: (context, index) {
                    final item = detail.lineItems[index];
                    final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                    final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['description'] ?? 'No Description'),
                        subtitle: Text('Qty: $qty x ${price.toStringAsFixed(2)} DZD'),
                        trailing: Text(
                          '${(qty * price).toStringAsFixed(2)} DZD',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
