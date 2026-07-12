import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/contracts_provider.dart';

class ContractsPage extends ConsumerWidget {
  const ContractsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsState = ref.watch(contractsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        centerTitle: true,
      ),
      body: contractsState.when(
        data: (contracts) {
          if (contracts.isEmpty) {
            return const Center(child: Text('No active contracts found.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(contractsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contracts.length,
              itemBuilder: (context, index) {
                final contract = contracts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(contract.contractTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(contract.contractorName ?? 'Unknown Vendor', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Total: ${contract.totalAmount.toStringAsFixed(2)} DZD'),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to details if needed in the future
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
