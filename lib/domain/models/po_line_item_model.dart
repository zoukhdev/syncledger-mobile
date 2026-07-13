class POLineItemModel {
  final String id;
  final String poId;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double total;

  POLineItemModel({
    required this.id,
    required this.poId,
    this.description,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.total = 0.0,
  });

  factory POLineItemModel.fromJson(Map<String, dynamic> json) {
    return POLineItemModel(
      id: json['id'],
      poId: json['po_id'],
      description: json['description'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'po_id': poId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      // total is GENERATED ALWAYS AS in DB, no need to send it unless creating locally
    };
  }
}
