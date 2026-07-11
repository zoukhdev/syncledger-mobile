class PaymentPhaseProgressModel {
  final String phaseId;
  final String contractId;
  final int phaseNumber;
  final String phaseName;
  final double phaseTotal;
  final double totalPaid;
  final double totalInvoiced;
  final double remainingBalance;

  PaymentPhaseProgressModel({
    required this.phaseId,
    required this.contractId,
    required this.phaseNumber,
    required this.phaseName,
    required this.phaseTotal,
    required this.totalPaid,
    required this.totalInvoiced,
    required this.remainingBalance,
  });

  factory PaymentPhaseProgressModel.fromJson(Map<String, dynamic> json) {
    return PaymentPhaseProgressModel(
      phaseId: json['phase_id'] as String,
      contractId: json['contract_id'] as String,
      phaseNumber: json['phase_number'] as int,
      phaseName: json['phase_name'] as String,
      phaseTotal: (json['phase_total'] as num).toDouble(),
      totalPaid: (json['total_paid'] as num).toDouble(),
      totalInvoiced: (json['total_invoiced'] as num).toDouble(),
      remainingBalance: (json['remaining_balance'] as num).toDouble(),
    );
  }
}
