import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/models/document_model.dart';
import 'package:uuid/uuid.dart';

final documentsProvider = FutureProvider.family<List<DocumentModel>, String>((ref, entityId) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('documents')
      .select('*')
      .eq('entity_id', entityId)
      .order('created_at', ascending: false);
      
  return (response as List).map((json) => DocumentModel.fromJson(json)).toList();
});

class DocumentUploader {
  static Future<void> uploadDocument({
    required File file,
    required String entityId,
    required String entityType,
    required String documentType,
    DateTime? expiryDate,
  }) async {
    final supabase = Supabase.instance.client;
    final fileExt = file.path.split('.').last;
    final fileName = '\${const Uuid().v4()}.$fileExt';
    final filePath = '$entityType/$entityId/$fileName';

    await supabase.storage.from('documents').upload(filePath, file);

    await supabase.from('documents').insert({
      'entity_type': entityType,
      'entity_id': entityId,
      'document_url': filePath,
      'document_type': documentType,
      'expiry_date': expiryDate?.toIso8601String(),
      'uploaded_by': supabase.auth.currentUser?.id,
    });
  }

  static Future<String> getSignedUrl(String path) async {
    final supabase = Supabase.instance.client;
    return await supabase.storage.from('documents').createSignedUrl(path, 60);
  }
}
