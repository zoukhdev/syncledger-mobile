import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../domain/models/purchase_order_model.dart';

final purchaseOrdersProvider = FutureProvider<List<PurchaseOrderModel>>((ref) async {
  final response = await Supabase.instance.client
      .from('purchase_orders')
      .select()
      .order('created_at', ascending: false);
      
  return (response as List).map((e) => PurchaseOrderModel.fromJson(e)).toList();
});

class PurchaseOrderDetail {
  final PurchaseOrderModel po;
  final String? vendorName;
  final List<dynamic> lineItems; // Can be typed to POLineItemModel later if needed

  PurchaseOrderDetail({required this.po, this.vendorName, required this.lineItems});
}

final purchaseOrderDetailProvider = FutureProvider.family<PurchaseOrderDetail, String>((ref, id) async {
  final response = await Supabase.instance.client
      .from('purchase_orders')
      .select('*, vendor:vendors(company_name), po_line_items(*)')
      .eq('id', id)
      .single();

  return PurchaseOrderDetail(
    po: PurchaseOrderModel.fromJson(response),
    vendorName: response['vendor']?['company_name'],
    lineItems: response['po_line_items'] as List,
  );
});
