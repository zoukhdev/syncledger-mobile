import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final staffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client.from('profiles').select();
  return List<Map<String, dynamic>>.from(res);
});

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffState = ref.watch(staffProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t?.staffDirectory ?? 'Staff Directory')),
      body: staffState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(t?.errorPrefix.replaceAll('{error}', err.toString()) ?? 'Error: $err')),
        data: (staffList) => ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(staff['full_name'] ?? (t?.unknownUser ?? 'Unknown User')),
              subtitle: Text(staff['role'] ?? 'staff'),
              trailing: staff['force_password_reset'] == true 
                  ? Chip(label: Text(t?.pendingPassword ?? 'Pending Password'), backgroundColor: Colors.orange) 
                  : Chip(label: Text(t?.active ?? 'Active'), backgroundColor: Colors.green),
            );
          },
        ),
      ),
    );
  }
}
