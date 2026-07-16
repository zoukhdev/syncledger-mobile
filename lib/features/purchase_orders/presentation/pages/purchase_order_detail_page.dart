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
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Theme.of(context).colorScheme.onSurface),
        title: const Text(
          'Purchase Order Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          detailAsync.maybeWhen(
            data: (detail) => IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0052CC)),
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
          
          Color badgeBgColor = const Color(0xFFE2E8F0);
          Color badgeTextColor = const Color(0xFF475569);
          if (po.status.toLowerCase() == 'pending') {
            badgeBgColor = const Color(0xFFFEF3C7);
            badgeTextColor = const Color(0xFFD97706);
          } else if (po.status.toLowerCase() == 'approved') {
            badgeBgColor = const Color(0xFFD1FAE5);
            badgeTextColor = const Color(0xFF059669);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Summary Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PO #${po.poNumber}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A), // Primary Navy
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          const SizedBox(height: 24),
                          _buildDetailRow('Vendor', detail.vendorName ?? 'SyncLedger'),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Issue Date', po.issuedAt != null ? DateFormat('yyyy-MM-dd').format(po.issuedAt!) : 'N/A'),
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Expected Delivery', po.expectedDelivery != null ? DateFormat('yyyy-MM-dd').format(po.expectedDelivery!) : 'N/A'),
                        ],
                      ),
                    ),
                    // Total Amount Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A), // Deep Navy background
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Total Amount: ${po.totalAmount.toStringAsFixed(2)} DZD',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Line Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: detail.lineItems.length,
                itemBuilder: (context, index) {
                  final item = detail.lineItems[index];
                  final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                  final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                  final total = qty * price;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['description'] ?? 'No Description',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: $qty × ${price.toStringAsFixed(2)} DZD',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} DZD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0052CC), // Brand Blue
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B), // Label Text
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B), // Value Text
          ),
        ),
      ],
    );
  }
}
