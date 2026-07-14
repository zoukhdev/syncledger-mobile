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
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF191C1E)),
        title: const Text(
          'Caisse (Cash Box)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF191C1E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF191C1E)),
            onPressed: () {},
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          final registers = data['registers'] as List<dynamic>;
          final transactions = data['transactions'] as List<dynamic>;

          if (registers.isEmpty) return const Center(child: Text('No cash registers found.'));

          final register = registers.first;
          
          String formattedLastReconciled = 'Never';
          if (register['last_reconciled_at'] != null) {
            final date = DateTime.parse(register['last_reconciled_at']).toLocal();
            formattedLastReconciled = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register: ${register['name']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Color(0xFF7C839B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Balance: ${register['balance'].toStringAsFixed(2)} ${register['currency']}',
                          style: const TextStyle(
                            fontSize: 28, // Using a slightly smaller size than 32 to fit on narrow screens safely
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last Reconciled: $formattedLastReconciled',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF76777D),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showAddTransactionDialog(context, register['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF131B2E), // Primary Navy
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Add Transaction',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showReconcileDialog(context, register),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text(
                                  'Reconcile',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6CF8BB).withOpacity(0.2), // Light Green bg
                                  foregroundColor: const Color(0xFF006C49), // Dark Green text
                                  side: BorderSide(color: const Color(0xFF006C49).withOpacity(0.2)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isOut = tx['transaction_type'] == 'out';
                          final isRec = tx['transaction_type'] == 'reconciliation';
                          final isNegativeRec = isRec && (tx['amount'] < 0);
                          final isError = isOut || isNegativeRec;
                          
                          final color = isError ? const Color(0xFFBA1A1A) : const Color(0xFF006C49);
                          final iconData = isOut ? Icons.arrow_upward : (isRec ? Icons.sync : Icons.arrow_downward);

                          // Attempt to parse expected vs actual from description if it's a reconciliation
                          String desc = tx['description'] ?? '';
                          String? expectedStr;
                          String? actualStr;
                          
                          if (isRec && desc.contains('Expected:') && desc.contains('Actual:')) {
                            final expMatch = RegExp(r'Expected: ([\d.]+)').firstMatch(desc);
                            final actMatch = RegExp(r'Actual: ([\d.]+)').firstMatch(desc);
                            if (expMatch != null && actMatch != null) {
                              expectedStr = expMatch.group(1);
                              actualStr = actMatch.group(1);
                              desc = 'Reconciliation discrepancy.';
                            }
                          }

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(iconData, color: color, size: 24),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF191C1E),
                                        ),
                                      ),
                                      if (isRec && expectedStr != null && actualStr != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F4F6),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFC6C6CD).withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Expected: $expectedStr', style: const TextStyle(fontSize: 14, color: Color(0xFF191C1E))),
                                              const SizedBox(height: 4),
                                              Text('Actual: $actualStr', style: const TextStyle(fontSize: 14, color: Color(0xFF191C1E))),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        DateTime.parse(tx['created_at']).toLocal().toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF76777D),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${tx['amount']} ${register['currency']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
