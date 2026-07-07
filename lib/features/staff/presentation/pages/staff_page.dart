import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final staffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client.from('profiles').select();
  return List<Map<String, dynamic>>.from(res);
});

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(staffProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Directory')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (staffList) => ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(staff['full_name'] ?? 'Unknown User'),
              subtitle: Text(staff['role'] ?? 'staff'),
              trailing: staff['force_password_reset'] == true 
                  ? const Chip(label: Text('Pending Password'), backgroundColor: Colors.orange) 
                  : const Chip(label: Text('Active'), backgroundColor: Colors.green),
            );
          },
        ),
      ),
    );
  }
}
