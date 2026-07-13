import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/contract_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final contractPhasesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, contractId) async {
  final supabase = Supabase.instance.client;
  final res = await supabase
      .from('payment_phases')
      .select()
      .eq('contract_id', contractId)
      .order('created_at');
  return List<Map<String, dynamic>>.from(res);
});

class ContractPhasesPage extends ConsumerWidget {
  final ContractModel contract;
  
  const ContractPhasesPage({super.key, required this.contract});

  void _showAddPhaseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Payment Phase'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Phase Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount (DZD)', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty || amountController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await Supabase.instance.client.from('payment_phases').insert({
                        'contract_id': contract.id,
                        'phase_name': nameController.text,
                        'amount': double.tryParse(amountController.text) ?? 0.0,
                        'status': 'pending',
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.refresh(contractPhasesProvider(contract.id));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final phasesAsync = ref.watch(contractPhasesProvider(contract.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.paymentPhases ?? 'Payment Phases'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPhaseDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.contractTitle, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Total: ${contract.totalAmount.toStringAsFixed(2)} DZD', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: phasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (phases) {
                if (phases.isEmpty) {
                  return Center(child: Text(t?.noPhasesDefined ?? 'No phases defined for this contract.'));
                }
                
                double allocated = phases.fold(0.0, (sum, phase) => sum + ((phase['amount'] as num?)?.toDouble() ?? 0.0));
                double remaining = contract.totalAmount - allocated;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${t?.allocated ?? 'Allocated:'} ${allocated.toStringAsFixed(2)} DZD', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          Text('${t?.netRemaining ?? 'Net Remaining:'} ${remaining.toStringAsFixed(2)} DZD', style: TextStyle(color: remaining < 0 ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: phases.length,
                        itemBuilder: (context, index) {
                          final phase = phases[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: phase['status'] == 'completed' ? Colors.green : Colors.orange,
                              child: Icon(phase['status'] == 'completed' ? Icons.check : Icons.hourglass_empty, color: Colors.white, size: 20),
                            ),
                            title: Text(phase['phase_name']),
                            subtitle: Text('Status: ${phase['status'] ?? 'pending'}'),
                            trailing: Text('${phase['amount']} DZD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
