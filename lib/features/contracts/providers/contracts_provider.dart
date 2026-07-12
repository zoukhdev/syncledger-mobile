import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/contract_model.dart';

final contractsProvider = FutureProvider.autoDispose<List<ContractModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('contracts')
      .select('*, contractors(company_name)')
      .order('created_at', ascending: false);

  final data = response as List<dynamic>;
  return data.map((json) => ContractModel.fromJson(json as Map<String, dynamic>)).toList();
});
