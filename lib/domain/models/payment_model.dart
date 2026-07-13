class PaymentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime paidAt;
  final String? method;
  final String? notes;

  PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.notes,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'],
      invoiceId: json['invoice_id'],
      amount: (json['amount'] as num).toDouble(),
      paidAt: DateTime.parse(json['paid_at']),
      method: json['method'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'invoice_id': invoiceId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
      'method': method,
      'notes': notes,
    };
  }
}
