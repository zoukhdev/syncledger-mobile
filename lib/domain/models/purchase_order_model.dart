class PurchaseOrderModel {
  final String id;
  final String? contractorId;
  final String poNumber;
  final String status;
  final double totalAmount;
  final DateTime? issuedAt;
  final DateTime? expectedDelivery;
  final String? notes;
  final DateTime? createdAt;

  PurchaseOrderModel({
    required this.id,
    this.contractorId,
    required this.poNumber,
    this.status = 'draft',
    this.totalAmount = 0.0,
    this.issuedAt,
    this.expectedDelivery,
    this.notes,
    this.createdAt,
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      id: json['id'],
      contractorId: json['contractor_id'],
      poNumber: json['po_number'],
      status: json['status'] ?? 'draft',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at']) : null,
      expectedDelivery: json['expected_delivery'] != null ? DateTime.parse(json['expected_delivery']) : null,
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'contractor_id': contractorId,
      'po_number': poNumber,
      'status': status,
      'total_amount': totalAmount,
      if (issuedAt != null) 'issued_at': issuedAt!.toIso8601String().split('T')[0],
      if (expectedDelivery != null) 'expected_delivery': expectedDelivery!.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }
}
