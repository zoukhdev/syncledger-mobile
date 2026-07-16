import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
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

  final invoicesRes = await Supabase.instance.client
      .from('invoices')
      .select('id, vendor_name, amount, status, invoice_type, created_at, contract_id, payment_phase_id')
      .order('created_at', ascending: false)
      .limit(200);

  final contracts = (contractsRes as List).map((c) => ContractModel.fromJson(c)).toList();
  final phases = (phasesRes as List).map((p) => PaymentPhaseProgressModel.fromJson(p)).toList();

  return {
    'contracts': contracts,
    'phases': phases,
    'invoices': invoicesRes,
  };
});

class RegistersPage extends ConsumerStatefulWidget {
  const RegistersPage({super.key});

  @override
  ConsumerState<RegistersPage> createState() => _RegistersPageState();
}

class _RegistersPageState extends ConsumerState<RegistersPage> {
  String? _selectedContractId;
  String? _expandedPhaseId;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(registersProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(t?.cashRegisters ?? 'Cash Registers'),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: cs.error))),
        data: (data) {
          final contracts = data['contracts'] as List<ContractModel>;
          final allPhases = data['phases'] as List<PaymentPhaseProgressModel>;
          final allInvoices = data['invoices'] as List<dynamic>;

          if (contracts.isEmpty) {
            return Center(child: Text(t?.noContractsFound ?? 'No contracts found.', style: TextStyle(color: cs.onSurface)));
          }

          if (_selectedContractId == null || !contracts.any((c) => c.id == _selectedContractId)) {
            _selectedContractId = contracts.first.id;
          }

          final selectedContract = contracts.firstWhere((c) => c.id == _selectedContractId);
          final phases = allPhases.where((p) => p.contractId == _selectedContractId).toList();
          final contractInvoices = allInvoices.where((i) => i['contract_id'] == _selectedContractId).toList();
          
          final totalPaid = phases.fold(0.0, (sum, p) => sum + p.totalPaid);
          final remaining = selectedContract.totalAmount - totalPaid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contract Selector Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Contract', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedContractId,
                          isExpanded: true,
                          dropdownColor: cs.surfaceContainerLow,
                          icon: Icon(Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
                          items: contracts.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedContractId = val;
                              _expandedPhaseId = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem(cs, t?.budget ?? 'Budget', selectedContract.totalAmount),
                        _buildSummaryItem(cs, t?.paidOut ?? 'Paid Out', totalPaid),
                        _buildSummaryItem(cs, t?.remaining ?? 'Remaining', remaining, isHighlight: remaining < 0),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Phases List
              Expanded(
                child: phases.isEmpty
                    ? Center(child: Text(t?.noPhasesDefined ?? 'No phases defined for this contract.', style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: phases.length,
                        itemBuilder: (context, index) {
                          final phase = phases[index];
                          final isExpanded = _expandedPhaseId == phase.phaseId;
                          final phaseInvoices = contractInvoices.where((i) => i['payment_phase_id'] == phase.phaseId).toList();
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: isExpanded ? cs.primary : cs.outlineVariant),
                            ),
                            color: cs.surfaceContainerLowest,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() {
                                  _expandedPhaseId = isExpanded ? null : phase.phaseId;
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(Icons.account_balance_wallet, color: cs.primary),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(t?.phase(phase.phaseNumber, phase.phaseName) ?? 'Phase ${phase.phaseNumber}: ${phase.phaseName}', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text('${phase.totalPaid.toStringAsFixed(2)} / ${phase.phaseTotal.toStringAsFixed(2)} DZD', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
                                      ],
                                    ),
                                  ),
                                  
                                  if (isExpanded)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerLow,
                                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text('Transactions (Wallets)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(height: 12),
                                          if (phaseInvoices.isEmpty)
                                            Text('No transactions for this phase.', style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic))
                                          else
                                            ...phaseInvoices.map((inv) {
                                              final isIncoming = inv['invoice_type'] == 'receivable';
                                              final amount = (inv['amount'] as num).toDouble();
                                              final date = DateTime.tryParse(inv['created_at'] ?? '') ?? DateTime.now();
                                              
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: cs.surfaceContainerLowest,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: cs.outlineVariant),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(inv['vendor_name'] ?? 'Unknown', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                                                          const SizedBox(height: 4),
                                                          Text(DateFormat('MMM dd, yyyy').format(date), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(2)} DZD',
                                                      style: TextStyle(
                                                        color: isIncoming ? Colors.green : Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                ],
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

  Widget _buildSummaryItem(ColorScheme cs, String label, double amount, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} DZD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.red : cs.onSurface,
          ),
        ),
      ],
    );
  }
}
