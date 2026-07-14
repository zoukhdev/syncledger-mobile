import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final caisseProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final registersRes = await Supabase.instance.client
      .from('cash_registers')
      .select('*')
      .order('created_at', ascending: true);

  List<dynamic> transactions = [];
  if (registersRes.isNotEmpty) {
    final txRes = await Supabase.instance.client
        .from('cash_transactions')
        .select('*')
        .eq('register_id', registersRes.first['id'])
        .order('created_at', ascending: false);
    transactions = txRes;
  }

  return {
    'registers': registersRes,
    'transactions': transactions,
  };
});

class CaissePage extends ConsumerStatefulWidget {
  const CaissePage({super.key});

  @override
  ConsumerState<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends ConsumerState<CaissePage> {
  Future<void> _showAddTransactionDialog(BuildContext context, String registerId) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'in';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Cash Transaction'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('IN'),
                      value: 'in',
                      groupValue: type,
                      onChanged: (val) => setState(() => type = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('OUT'),
                      value: 'out',
                      groupValue: type,
                      onChanged: (val) => setState(() => type = val!),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (DZD)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null || descriptionController.text.isEmpty) return;

              // 1. Insert Tx
              await Supabase.instance.client.from('cash_transactions').insert({
                'register_id': registerId,
                'transaction_type': type,
                'amount': amt,
                'description': descriptionController.text,
              });

              // 2. Update balance
              final currentReg = await Supabase.instance.client
                  .from('cash_registers')
                  .select('balance')
                  .eq('id', registerId)
                  .single();

              final newBal = type == 'in' ? currentReg['balance'] + amt : currentReg['balance'] - amt;
              await Supabase.instance.client.from('cash_registers').update({'balance': newBal}).eq('id', registerId);

              ref.refresh(caisseProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReconcileDialog(BuildContext context, Map<String, dynamic> register) async {
    final actualController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconcile Cash Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('System Balance: ${register['balance']} ${register['currency']}'),
            const SizedBox(height: 16),
            TextField(
              controller: actualController,
              decoration: const InputDecoration(labelText: 'Actual Physical Cash'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final actual = double.tryParse(actualController.text);
              if (actual == null) return;

              final diff = actual - register['balance'];
              if (diff != 0) {
                await Supabase.instance.client.from('cash_transactions').insert({
                  'register_id': register['id'],
                  'transaction_type': 'reconciliation',
                  'amount': diff,
                  'description': 'Reconciliation discrepancy. Expected: ${register['balance']}, Actual: $actual',
                });
              }

              await Supabase.instance.client.from('cash_registers').update({
                'balance': actual,
                'last_reconciled_at': DateTime.now().toIso8601String(),
              }).eq('id', register['id']);

              ref.refresh(caisseProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(caisseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF434653)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cash Registers',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
            color: Color(0xFF1B1C1D),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF094CB2), // Primary
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          asyncData.whenData((data) {
            final registers = data['registers'] as List<dynamic>;
            if (registers.isNotEmpty) {
               _showAddTransactionDialog(context, registers.first['id']);
            }
          });
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          final registers = data['registers'] as List<dynamic>;
          final transactions = data['transactions'] as List<dynamic>;

          if (registers.isEmpty) return const Center(child: Text('No cash registers found.'));

          final register = registers.first;
          
          double totalIn = 0;
          double totalOut = 0;
          for (var tx in transactions) {
            final amt = double.parse(tx['amount'].toString());
            if (tx['transaction_type'] == 'in') {
              totalIn += amt;
            } else if (tx['transaction_type'] == 'out') {
              totalOut += amt;
            } else if (tx['transaction_type'] == 'reconciliation') {
              if (amt < 0) totalOut += amt.abs();
              else totalIn += amt;
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)), // ring-1 ring-outline-variant/15
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            register['name'],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B1C1D),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEDEE), // bg-surface-container
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontFamily: 'Public Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Color(0xFF737784), // text-outline
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: Color(0xFFE3E2E3)), // border-surface-variant

                    // Top Level Summary (3 cols)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL IN',
                                style: TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF434653), // text-on-surface-variant
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${totalIn.toStringAsFixed(2)} ${register['currency']}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B1C1D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL OUT',
                                style: TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF434653), 
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${totalOut.toStringAsFixed(2)} ${register['currency']}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF434653), // slightly muted
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BALANCE',
                                style: TextStyle(
                                  fontFamily: 'Public Sans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF434653),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${register['balance'].toStringAsFixed(2)} ${register['currency']}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF094CB2), // text-primary
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Transactions Section (Replacing Payment Phases)
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Color(0xFF6D5E00)), // text-tertiary
                        const SizedBox(width: 8),
                        const Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1C1D),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showReconcileDialog(context, register),
                          child: const Text('Reconcile', style: TextStyle(color: Color(0xFF094CB2))),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (transactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3F4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No transactions yet.',
                            style: TextStyle(fontFamily: 'Inter', fontStyle: FontStyle.italic, color: Color(0xFF434653)),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isOut = tx['transaction_type'] == 'out';
                          final isRec = tx['transaction_type'] == 'reconciliation';
                          final isNegativeRec = isRec && (tx['amount'] < 0);
                          final isError = isOut || isNegativeRec;
                          
                          final color = isError ? const Color(0xFFBA1A1A) : const Color(0xFF094CB2); // Error or Primary
                          
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3F4), // bg-surface-container-low
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.transparent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              tx['description'] ?? 'Transaction',
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1B1C1D),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isRec)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE3E2E3),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text('Recon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateTime.parse(tx['created_at']).toLocal().toString().split('.')[0], // simpler date
                                        style: const TextStyle(
                                          fontFamily: 'Public Sans',
                                          fontSize: 11,
                                          color: Color(0xFF434653),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'AMOUNT',
                                      style: TextStyle(
                                        fontFamily: 'Public Sans',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: Color(0xFF434653),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${tx['amount'].toString()} DZD',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: color,
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
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
