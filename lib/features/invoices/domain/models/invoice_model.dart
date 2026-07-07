class InvoiceModel {
  final String id;
  final String vendorName;
  final String invoiceType;
  final double amount;
  final DateTime date;
  final DateTime dueDate;
  final String status;
  final String? documentUrl;
  final String? paymentProofUrl;
  final String? notes;

  InvoiceModel({
    required this.id,
    required this.vendorName,
    this.invoiceType = 'payable',
    required this.amount,
    required this.date,
    required this.dueDate,
    required this.status,
    this.documentUrl,
    this.paymentProofUrl,
    this.notes,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      vendorName: json['vendor_name'] as String,
      invoiceType: json['invoice_type'] as String? ?? 'payable',
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['invoice_date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
      documentUrl: json['document_url'] as String?,
    );
  }
}
