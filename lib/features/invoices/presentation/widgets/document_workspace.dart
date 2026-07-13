import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/invoice_model.dart';
import '../../../auth/providers/auth_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../scanner/presentation/pages/ocr_scan_page.dart';
import '../providers/payments_provider.dart';
import '../../../../domain/models/payment_model.dart';

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
                            const SizedBox(height: 16),

                            // Payment Progress
                            Consumer(
                              builder: (context, ref, child) {
                                final paymentsAsync = ref.watch(paymentsProvider(widget.invoice.id));
                                return paymentsAsync.when(
                                  loading: () => const CircularProgressIndicator(),
                                  error: (err, stack) => Text('Error loading payments: $err'),
                                  data: (payments) {
                                    final totalPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
                                    final progress = widget.invoice.amount > 0 ? (totalPaid / widget.invoice.amount) : 0.0;
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Payment Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text('${(progress * 100).toStringAsFixed(1)}%'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                                        const SizedBox(height: 4),
                                        Text('${totalPaid.toStringAsFixed(2)} DA paid of ${widget.invoice.amount.toStringAsFixed(2)} DA', style: Theme.of(context).textTheme.bodySmall),
                                        
                                        if (payments.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ...payments.map((p) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            title: Text('${p.amount.toStringAsFixed(2)} DA - ${p.method ?? 'Unknown'}'),
                                            subtitle: Text("${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}"),
                                            trailing: p.notes != null && p.notes!.isNotEmpty ? const Icon(Icons.note) : null,
                                            onTap: () {
                                              if (p.notes != null && p.notes!.isNotEmpty) {
                                                showDialog(
                                                  context: context, 
                                                  builder: (c) => AlertDialog(
                                                    title: const Text('Payment Notes'),
                                                    content: Text(p.notes!),
                                                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
                                                  )
                                                );
                                              }
                                            },
                                          )).toList(),
                                        ],
                                        const SizedBox(height: 8),
                                        if (totalPaid < widget.invoice.amount)
                                          ElevatedButton.icon(
                                            onPressed: () => _recordPaymentDialog(widget.invoice.amount - totalPaid),
                                            icon: const Icon(Icons.payment),
                                            label: const Text('Record Payment'),
                                          ),
                                      ],
                                    );
                                  }
                                );
                              }
                            ),
                            
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

  void _recordPaymentDialog(double maxAmount) {
    double amount = maxAmount;
    String method = 'cash';
    String notes = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Record Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: amount.toString(),
                      decoration: const InputDecoration(labelText: 'Amount (DA)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => amount = double.tryParse(val) ?? 0,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'baridimob', child: Text('BaridiMob')),
                        DropdownMenuItem(value: 'wimpay', child: Text('Wimpay')),
                        DropdownMenuItem(value: 'ccp', child: Text('CCP')),
                      ],
                      onChanged: (val) {
                        if (val != null) setStateSB(() => method = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                      onChanged: (val) => notes = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await Supabase.instance.client.from('payments').insert({
                        'invoice_id': widget.invoice.id,
                        'amount': amount,
                        'method': method,
                        'notes': notes,
                      });
                      
                      if (mounted) {
                        ref.invalidate(paymentsProvider(widget.invoice.id));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record payment: $e')));
                    }
                  }, 
                  child: const Text('Save')
                ),
              ],
            );
          }
        );
      }
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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
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
