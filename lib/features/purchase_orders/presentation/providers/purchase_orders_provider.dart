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
