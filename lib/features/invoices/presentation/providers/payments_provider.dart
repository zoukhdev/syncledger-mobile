import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../domain/models/payment_model.dart';

final paymentsProvider = FutureProvider.family<List<PaymentModel>, String>((ref, invoiceId) async {
  final response = await Supabase.instance.client
      .from('payments')
      .select()
      .eq('invoice_id', invoiceId)
      .order('paid_at', ascending: false);
      
  return (response as List).map((e) => PaymentModel.fromJson(e)).toList();
});
