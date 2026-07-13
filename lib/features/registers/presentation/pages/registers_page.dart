import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../contracts/providers/contracts_provider.dart';
import '../../domain/models/contract_model.dart';
import '../../domain/models/payment_phase_progress_model.dart';

final registersProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final contractsRes = await Supabase.instance.client
      .from('contracts')
      .select('id, contract_title, total_amount')
      .order('created_at', ascending: false);
      
  final phasesRes = await Supabase.instance.client
      .from('payment_phase_progress')
      .select()
      .order('phase_number', ascending: true);

  final contracts = (contractsRes as List).map((c) => ContractModel.fromJson(c)).toList();
  final phases = (phasesRes as List).map((p) => PaymentPhaseProgressModel.fromJson(p)).toList();

  return {
    'contracts': contracts,
    'phases': phases,
  };
});

class RegistersPage extends ConsumerWidget {
  const RegistersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsState = ref.watch(contractsProvider);
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t?.cashRegisters ?? 'Cash Registers')),
      body: contractsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(t?.errorPrefix.replaceAll('{error}', err.toString()) ?? 'Error: $err')),
        data: (contracts) {
          if (contracts.isEmpty) {
            return Center(child: Text(t?.noContractsFound ?? 'No contracts found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
              final phases = contract.phases ?? [];
              
              final totalPaid = phases.fold(0.0, (sum, p) => sum + p.totalPaid);
              final remaining = contract.totalAmount - totalPaid;

              return Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contract.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        alignment: WrapAlignment.start,
                        children: [
                          _buildSummaryItem(context, t?.budget ?? 'Budget', contract.totalAmount),
                          _buildSummaryItem(context, t?.paidOut ?? 'Paid Out', totalPaid),
                          _buildSummaryItem(context, t?.remaining ?? 'Remaining', remaining, isHighlight: remaining < 0),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(t?.paymentPhases ?? 'Payment Phases', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (phases.isEmpty)
                        Text(t?.noPhasesDefined ?? 'No phases defined for this contract.', style: const TextStyle(color: Colors.grey))
                      else
                        ...phases.map((phase) {
                          return Card(
                            color: theme.colorScheme.surfaceContainerHighest,
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t?.phase.replaceAll('{number}', phase.phaseNumber.toString()).replaceAll('{name}', phase.phaseName) ?? 'Phase ${phase.phaseNumber}: ${phase.phaseName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(t?.allocated ?? 'Allocated:', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                      Text('${phase.phaseTotal.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(t?.netRemaining ?? 'Net Remaining:', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                      Text(
                                        '${phase.remainingBalance.toStringAsFixed(2)} DZD', 
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: phase.remainingBalance >= 0 ? Colors.green : Colors.red),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, double amount, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          '${amount.toStringAsFixed(2)} DZD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
