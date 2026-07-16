import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'YOUR_SUPABASE_URL';
  final supabaseKey = 'YOUR_SUPABASE_ANON_KEY';
  
  final env = File('.env').readAsStringSync();
  String url = '';
  String key = '';
  for (var line in env.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1].trim();
  }
  
  final client = SupabaseClient(url, key);
  try {
    final res = await client.from('contracts').select().limit(1);
    if ((res as List).isNotEmpty) {
      print(res[0].keys.toList());
    } else {
      print('No contracts found, inserting one to test...');
    }
  } catch (e) {
    print('Error: $e');
  }
}
