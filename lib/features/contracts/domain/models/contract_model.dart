class ContractModel {
  final String id;
  final String contractTitle;
  final double totalAmount;
  final String? status;
  final String? contractorName;

  ContractModel({
    required this.id,
    required this.contractTitle,
    required this.totalAmount,
    this.status,
    this.contractorName,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      id: json['id'] as String,
      contractTitle: json['contract_title'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String?,
      contractorName: json['contractors'] != null ? json['contractors']['company_name'] as String? : null,
    );
  }
}
