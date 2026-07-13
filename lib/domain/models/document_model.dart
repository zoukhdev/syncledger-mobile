class DocumentModel {
  final String id;
  final String entityType;
  final String entityId;
  final String documentUrl;
  final String documentType;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final String? uploadedBy;

  DocumentModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.documentUrl,
    required this.documentType,
    this.expiryDate,
    required this.createdAt,
    this.uploadedBy,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      documentUrl: json['document_url'] as String,
      documentType: json['document_type'] as String,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      uploadedBy: json['uploaded_by'] as String?,
    );
  }
}
