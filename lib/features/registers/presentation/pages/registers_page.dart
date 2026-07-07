import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final registersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client.from('wallets').select();
  return List<Map<String, dynamic>>.from(res);
});

class RegistersPage extends ConsumerWidget {
  const RegistersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(registersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Registers')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (registers) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: registers.length,
          itemBuilder: (context, index) {
            final reg = registers[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(reg['name'], style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('${(reg['balance'] as num).toDouble().toStringAsFixed(2)} DZD', 
                         style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Chip(label: Text(reg['currency'])),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
