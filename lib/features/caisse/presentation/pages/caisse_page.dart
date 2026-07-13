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
      appBar: AppBar(title: const Text('Caisse (Cash Box)')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) {
          final registers = data['registers'] as List<dynamic>;
          final transactions = data['transactions'] as List<dynamic>;

          if (registers.isEmpty) return const Center(child: Text('No cash registers found.'));

          final register = registers.first;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Register: ${register['name']}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Balance: ${register['balance']} ${register['currency']}', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text('Last Reconciled: ${register['last_reconciled_at'] != null ? DateTime.parse(register['last_reconciled_at']).toLocal().toString() : 'Never'}', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showAddTransactionDialog(context, register['id']),
                              icon: const Icon(Icons.add),
                              label: Text(AppLocalizations.of(context)?.addContractor ?? 'New Transaction'), // Temporary fallback or new string
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showReconcileDialog(context, register),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(AppLocalizations.of(context)?.caisse ?? 'Reconcile'), // Add string 'reconcile' later
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: transactions.isEmpty
                    ? const Center(child: Text('No transactions yet.'))
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isOut = tx['transaction_type'] == 'out';
                          final isRec = tx['transaction_type'] == 'reconciliation';

                          return ListTile(
                            leading: Icon(
                              isOut ? Icons.arrow_upward : (isRec ? Icons.sync : Icons.arrow_downward),
                              color: isOut || (isRec && tx['amount'] < 0) ? Colors.red : Colors.green,
                            ),
                            title: Text(tx['description']),
                            subtitle: Text(DateTime.parse(tx['created_at']).toLocal().toString()),
                            trailing: Text(
                              '${tx['amount']} ${register['currency']}',
                              style: TextStyle(
                                color: isOut || (isRec && tx['amount'] < 0) ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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
