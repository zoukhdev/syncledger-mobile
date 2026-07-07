import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/invoice_model.dart';
import '../../../auth/providers/auth_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../scanner/presentation/pages/ocr_scan_page.dart';

class DocumentWorkspace extends ConsumerStatefulWidget {
  final InvoiceModel invoice;
  final VoidCallback onClose;

  const DocumentWorkspace({
    super.key,
    required this.invoice,
    required this.onClose,
  });

  @override
  ConsumerState<DocumentWorkspace> createState() => _DocumentWorkspaceState();
}

class _DocumentWorkspaceState extends ConsumerState<DocumentWorkspace> {
  late TextEditingController _notesController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.invoice.notes);
  }

  @override
  void didUpdateWidget(covariant DocumentWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoice.id != widget.invoice.id) {
      _notesController.text = widget.invoice.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onNotesChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      // In a real app, this is where we'd call Supabase to update the notes
      debugPrint('Auto-saving notes for invoice ${widget.invoice.id}: $value');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isApproved = widget.invoice.status == 'approved';
    final role = ref.watch(authProvider).value?.role ?? 'staff';

    return Card(
      margin: EdgeInsets.zero, // Removed margin since it's now in a dialog
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Workspace: ${widget.invoice.vendorName}',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close Workspace (Esc)',
                ),
              ],
            ),
          ),
          
          // Split Panel Content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 600;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left (Document)
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Container(
                        constraints: BoxConstraints(minHeight: isMobile ? 200 : 0),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                widget.invoice.documentUrl == null 
                                  ? 'No Document Attached'
                                  : 'Loading Document...',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    if (!isMobile) const VerticalDivider(width: 1),
                    if (isMobile) const Divider(height: 1),

                    // Right (Data & Notes)
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Details', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            
                            _DetailRow(label: 'Amount', value: '${widget.invoice.amount.toStringAsFixed(2)} DA'),
                            const SizedBox(height: 8),
                            _DetailRow(label: 'Date', value: "${widget.invoice.date.day}/${widget.invoice.date.month}/${widget.invoice.date.year}"),
                            
                            const SizedBox(height: 32),
                            Text('Notes', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            
                            SizedBox(
                              height: 200,
                              child: TextField(
                                controller: _notesController,
                                maxLines: null,
                                expands: true,
                                enabled: !isApproved, // Edge-case enforcement: Lock fields if approved
                                decoration: InputDecoration(
                                  hintText: isApproved 
                                    ? 'Notes locked.'
                                    : 'Type notes here...',
                                  border: const OutlineInputBorder(),
                                  filled: isApproved,
                                  fillColor: isApproved ? Colors.grey.shade100 : null,
                                ),
                                onChanged: _onNotesChanged,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
          
          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Image'),
                      onPressed: _uploadImage,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Scan Invoice'),
                      onPressed: _scanInvoice,
                    ),
                  ],
                ),
                if (role == 'owner' || role == 'accountant')
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isApproved) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                          onPressed: () => _updateStatus('flagged_rejected'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, color: Colors.orange),
                          label: const Text('Return to Rectify', style: TextStyle(color: Colors.orange)),
                          onPressed: () => _updateStatus('pending_review'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          label: const Text('Delete', style: TextStyle(color: Colors.grey)),
                          onPressed: _deleteInvoice,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => _updateStatus('approved'),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.undo),
                          label: const Text('Revoke Approval'),
                          onPressed: () => _updateStatus('pending_review'),
                        ),
                      ]
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('invoices')
          .update({'status': newStatus})
          .eq('id', widget.invoice.id);
      
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice $newStatus')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    try {
      await Supabase.instance.client.from('invoices').delete().eq('id', widget.invoice.id);
      if (mounted) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        
        await Supabase.instance.client.storage.from('receipts').upload(fileName, file);
        final url = Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
        
        await Supabase.instance.client.from('invoices').update({
          'document_url': url,
        }).eq('id', widget.invoice.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully')));
          // The real-time listener will pick up the change
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _scanInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OcrScanPage()),
    );
    
    if (result != null && result is Map) {
      try {
        final imagePath = result['imagePath'] as String;
        final file = File(imagePath);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await Supabase.instance.client.storage.from('receipts').upload(fileName, file);
        final url = Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
        
        await Supabase.instance.client.from('invoices').update({
          'document_url': url,
        }).eq('id', widget.invoice.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan uploaded successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan upload failed: $e')));
        }
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }
}
