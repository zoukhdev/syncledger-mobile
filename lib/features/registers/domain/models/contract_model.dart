class ContractModel {
  final String id;
  final String title;
  final double totalAmount;

  ContractModel({
    required this.id,
    required this.title,
    required this.totalAmount,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      id: json['id'] as String,
      title: json['contract_title'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
    );
  }
}
