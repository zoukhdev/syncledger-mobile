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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 672, // max-w-2xl
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFF2F0F1))), // inverse-on-surface as ghost-border
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFEDEE), // surface-container
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.work, color: Color(0xFF434653)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('WORKSPACE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                  Text(
                                    widget.invoice.vendorName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B1C1D)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF434653)),
                            onPressed: widget.onClose,
                            hoverColor: const Color(0xFFE9E8E9),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Document Preview
                            const Text('DOCUMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: widget.invoice.documentUrl != null ? () {
                                // Real implementation would open the full document
                              } : null,
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3F4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE3E2E3)),
                                  image: widget.invoice.documentUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(widget.invoice.documentUrl!),
                                          fit: BoxFit.cover,
                                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                                        )
                                      : null,
                                ),
                                child: widget.invoice.documentUrl == null
                                    ? const Center(child: Text('No Document Attached', style: TextStyle(color: Color(0xFF737784))))
                                    : Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.visibility, size: 16),
                                              SizedBox(width: 8),
                                              Text('View Full Document', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Details Grid
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('TOTAL AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              widget.invoice.amount.toStringAsFixed(2),
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF094CB2)),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('DZD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF434653))),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      const Text('ISSUE DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF434653)),
                                          const SizedBox(width: 8),
                                          Text("${widget.invoice.date.day}/${widget.invoice.date.month}/${widget.invoice.date.year}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1B1C1D))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Right Column
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final paymentsAsync = ref.watch(paymentsProvider(widget.invoice.id));
                                      return paymentsAsync.when(
                                        loading: () => const Center(child: CircularProgressIndicator()),
                                        error: (err, stack) => Text('Error: $err'),
                                        data: (payments) {
                                          final totalPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
                                          final progress = widget.invoice.amount > 0 ? (totalPaid / widget.invoice.amount) : 0.0;
                                          final remaining = (widget.invoice.amount - totalPaid).clamp(0.0, double.infinity);
                                          
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('PAYMENT PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                              const SizedBox(height: 12),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: progress.clamp(0.0, 1.0),
                                                  minHeight: 10,
                                                  backgroundColor: const Color(0xFFE9E8E9),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D5E00)), // tertiary
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('Paid: ${totalPaid.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF434653))),
                                                  Text('Remaining: ${remaining.toStringAsFixed(2)} DZD', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF434653))),
                                                ],
                                              ),
                                              const SizedBox(height: 24),
                                              const Text('STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFBFAB49).withOpacity(0.2), // tertiary-container / 20
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF6D5E00), // tertiary
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(widget.invoice.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6D5E00))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      );
                                    }
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Notes Display
                            if (widget.invoice.notes != null && widget.invoice.notes!.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                                  TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Edit', style: TextStyle(fontSize: 14, color: Color(0xFF094CB2))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3F4), // surface-container-low
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE3E2E3)),
                                ),
                                child: Text(
                                  widget.invoice.notes!,
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF434653), height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Associated Files
                            const Text('ASSOCIATED FILES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                InkWell(
                                  onTap: _uploadImage,
                                  child: Container(
                                    height: 80,
                                    width: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFEDEE),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE3E2E3)),
                                    ),
                                    child: const Center(child: Icon(Icons.add, color: Color(0xFF434653))),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Add Notes
                            const Text('ADD NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF434653), letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              enabled: !isApproved,
                              onChanged: _onNotesChanged,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: isApproved ? 'Notes locked.' : 'Type notes here...',
                                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF737784)),
                                filled: true,
                                fillColor: const Color(0xFFF5F3F4), // surface-container-low
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF094CB2), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer Actions
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFF2F0F1))),
                      ),
                      child: Column(
                        children: [
                          // Primary Actions
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _scanInvoice,
                                icon: const Icon(Icons.document_scanner, size: 16),
                                label: const Text('Scan Invoice'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF094CB2),
                                  side: const BorderSide(color: Color(0xFF094CB2), width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final progressState = ref.read(paymentsProvider(widget.invoice.id));
                                  double maxAmount = widget.invoice.amount;
                                  progressState.whenData((payments) {
                                    final totalPaid = payments.fold(0.0, (sum, item) => sum + item.amount);
                                    maxAmount = (widget.invoice.amount - totalPaid).clamp(0.0, double.infinity);
                                  });
                                  if (maxAmount > 0) {
                                    _recordPaymentDialog(maxAmount);
                                  }
                                },
                                icon: const Icon(Icons.payments, size: 16),
                                label: const Text('Record Payment'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: const Color(0xFF094CB2),
                                  backgroundColor: const Color(0xFFE9E8E9), // surface-container-high
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                              if (role == 'owner' || role == 'accountant')
                                ElevatedButton.icon(
                                  onPressed: !isApproved ? () => _updateStatus('approved') : null,
                                  icon: const Icon(Icons.check_circle, size: 16),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: const Color(0xFF094CB2),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                ),
                            ],
                          ),
                          
                          // Secondary Actions
                          if (role == 'owner' || role == 'accountant') ...[
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFEFEDEE)),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 24,
                              runSpacing: 16,
                              children: [
                                if (!isApproved) ...[
                                  _SecondaryActionButton(
                                    icon: Icons.close,
                                    label: 'Reject',
                                    color: Colors.red,
                                    onPressed: () => _updateStatus('flagged_rejected'),
                                  ),
                                  _SecondaryActionButton(
                                    icon: Icons.reply,
                                    label: 'Rectify',
                                    color: const Color(0xFF094CB2),
                                    onPressed: () => _updateStatus('pending_review'),
                                  ),
                                  _SecondaryActionButton(
                                    icon: Icons.delete,
                                    label: 'Delete',
                                    color: Colors.red,
                                    onPressed: _deleteInvoice,
                                  ),
                                ] else ...[
                                  _SecondaryActionButton(
                                    icon: Icons.undo,
                                    label: 'Revoke Approval',
                                    color: const Color(0xFF094CB2),
                                    onPressed: () => _updateStatus('pending_review'),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
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
        final urlRes = await Supabase.instance.client.storage.from('receipts').createSignedUrl(fileName, 3600);
        
        await Supabase.instance.client.from('invoices').update({
          'document_url': urlRes,
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
        final urlRes = await Supabase.instance.client.storage.from('receipts').createSignedUrl(fileName, 3600);
        
        await Supabase.instance.client.from('invoices').update({
          'document_url': urlRes,
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

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEFEDEE), // surface-container
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
