import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final auditProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('audit_logs')
      .select('*, profiles:user_id(full_name)')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res);
});

class AuditLogsPage extends ConsumerWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(auditProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (logs) => ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final log = logs[index];
            final profile = log['profiles'];
            final name = profile != null ? profile['full_name'] : 'Unknown';
            return ListTile(
              title: Text('${log['action']} - ${log['resource_type']}'),
              subtitle: Text('By $name on ${DateTime.parse(log['created_at']).toLocal()}'),
            );
          },
        ),
      ),
    );
  }
}
