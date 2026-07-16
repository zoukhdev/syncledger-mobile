import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'YOUR_SUPABASE_URL';
  final supabaseKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // read from .env
  final env = File('.env').readAsStringSync();
  String? url;
  String? key;
  for (var line in env.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1].trim();
  }
  
  final client = SupabaseClient(url!, key!);
  final res = await client.from('audit_logs').select().limit(1);
  print(res);
}
