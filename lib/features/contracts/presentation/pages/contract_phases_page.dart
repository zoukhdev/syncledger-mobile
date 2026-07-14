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
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF094CB2)), // text-primary
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Phases',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
            color: Color(0xFF1B1C1D), // text-on-background
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF094CB2)),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF094CB2), // bg-primary
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showAddPhaseDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: phasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (phases) {
          double allocated = phases.fold(0.0, (sum, phase) => sum + ((phase['amount'] as num?)?.toDouble() ?? 0.0));
          double remaining = contract.totalAmount - allocated;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Hero Summary Section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)), // outline-variant/15
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL ALLOCATED',
                            style: TextStyle(
                              fontFamily: 'Inter', // mapped from label
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Color(0xFF434653), // text-on-surface-variant
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${allocated.toStringAsFixed(2)} DZD',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32, // Display size
                              fontWeight: FontWeight.w900, // Black
                              color: Color(0xFF094CB2), // text-primary
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 64,
                      color: const Color(0xFFC3C6D5).withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NET REMAINING',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Color(0xFF434653),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${remaining.toStringAsFixed(2)} DZD',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6D5E00), // text-tertiary
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Project Timeline',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Color(0xFF1B1C1D),
                ),
              ),
              const SizedBox(height: 24),
              
              if (phases.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text(
                      'No phases defined yet.',
                      style: TextStyle(color: Color(0xFF434653), fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: phases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final phase = phases[index];
                    final isCompleted = phase['status'] == 'completed';
                    
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      ),
                      child: Row(
                        children: [
                          // Icon container
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3E2E3), // bg-surface-variant
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle : Icons.hourglass_empty,
                              color: const Color(0xFF737784), // text-outline
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Title & Badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        phase['phase_name'] ?? 'Phase',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B1C1D),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3E2E3), // bg-surface-variant
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        (phase['status'] ?? 'pending').toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF434653), // text-on-surface-variant
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Development and core feature implementation.', // Or phase description if added to db
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF434653),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // Allocated amount
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ALLOCATED',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF434653),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(phase['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'} DZD',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B1C1D),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
