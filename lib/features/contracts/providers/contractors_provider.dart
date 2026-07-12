import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final contractorsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('contractors')
      .select('id, company_name')
      .order('company_name', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});
