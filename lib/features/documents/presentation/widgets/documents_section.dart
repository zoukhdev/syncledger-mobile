import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/documents_provider.dart';

class DocumentsSection extends ConsumerWidget {
  final String entityId;
  final String entityType;

  const DocumentsSection({super.key, required this.entityId, required this.entityType});

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);

      // Simple dialog for document type and expiry
      String docType = 'Contract';
      DateTime? expiryDate;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Document Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Document Type (e.g. Receipt)'),
                    onChanged: (v) => docType = v,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => expiryDate = d);
                    },
                    child: Text(expiryDate == null ? 'Set Expiry Date' : 'Exp: ${expiryDate!.toIso8601String().split('T')[0]}'),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
              ],
            );
          }
        )
      ).then((proceed) async {
        if (proceed == true) {
          try {
            await DocumentUploader.uploadDocument(
              file: file,
              entityId: entityId,
              entityType: entityType,
              documentType: docType,
              expiryDate: expiryDate,
            );
            ref.invalidate(documentsProvider(entityId));
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider(entityId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload'),
                onPressed: () => _uploadDocument(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (docs) {
              if (docs.isEmpty) {
                return const Center(child: Text('No documents attached.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final isExpired = doc.expiryDate?.isBefore(DateTime.now()) ?? false;
                  final isExpiringSoon = doc.expiryDate != null && 
                    doc.expiryDate!.difference(DateTime.now()).inDays < 30 &&
                    !isExpired;

                  return ListTile(
                    leading: const Icon(Icons.file_copy, color: Colors.blue),
                    title: Text(doc.documentType),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.createdAt.toIso8601String().split('T')[0]),
                        if (doc.expiryDate != null)
                          Text(
                            'Exp: ${doc.expiryDate!.toIso8601String().split('T')[0]}',
                            style: TextStyle(
                              color: isExpired ? Colors.red : isExpiringSoon ? Colors.orange : Colors.grey,
                              fontWeight: (isExpired || isExpiringSoon) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        try {
                          final url = await DocumentUploader.getSignedUrl(doc.documentUrl);
                          if (!await launchUrl(Uri.parse(url))) {
                            throw Exception('Could not launch url');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open: $e')));
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
