import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/models/invoice_model.dart';
import '../../../scanner/presentation/pages/ocr_scan_page.dart';
import '../../../../core/sync/sync_service.dart';

class InvoiceFormDialog extends StatefulWidget {
  final InvoiceModel? invoice;
  const InvoiceFormDialog({super.key, this.invoice});

  @override
  State<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vendorController;
  late TextEditingController _amountController;
  late String _invoiceType;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  String? _documentUrl;
  
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _phases = [];
  String? _selectedContractId;
  String? _selectedPhaseId;
  
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: widget.invoice?.vendorName ?? '');
    _amountController = TextEditingController(text: widget.invoice?.amount.toString() ?? '');
    _invoiceType = widget.invoice?.invoiceType ?? 'payable';
    _invoiceDate = widget.invoice?.date ?? DateTime.now();
    _dueDate = widget.invoice?.dueDate ?? DateTime.now();
    _documentUrl = widget.invoice?.documentUrl;
    
    _selectedContractId = widget.invoice?.contractId.isNotEmpty == true ? widget.invoice!.contractId : null;
    _selectedPhaseId = widget.invoice?.paymentPhaseId.isNotEmpty == true ? widget.invoice!.paymentPhaseId : null;
    
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        // If offline, we might not be able to fetch them unless cached.
        // Assuming simple online fetch for now.
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }
      final contractsRes = await Supabase.instance.client.from('contracts').select('id, contract_title');
      final phasesRes = await Supabase.instance.client.from('payment_phases').select('id, contract_id, phase_name');
      if (mounted) {
        setState(() {
          _contracts = List<Map<String, dynamic>>.from(contractsRes);
          _phases = List<Map<String, dynamic>>.from(phasesRes);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedContractId == null || _selectedPhaseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a contract and a phase.')));
        return;
      }
      setState(() => _isLoading = true);

      try {
        final Map<String, dynamic> data = {
          'vendor_name': _vendorController.text,
          'invoice_type': _invoiceType,
          'amount': double.parse(_amountController.text),
          'invoice_date': _invoiceDate.toIso8601String(),
          'due_date': _dueDate.toIso8601String(),
          'currency': 'DZD',
          'contract_id': _selectedContractId,
          'payment_phase_id': _selectedPhaseId,
          if (_documentUrl != null) 'document_url': _documentUrl,
        };

        if (widget.invoice == null) {
          data['status'] = 'pending_approval';
          data['created_by'] = Supabase.instance.client.auth.currentUser?.id;
          
          final connectivity = await Connectivity().checkConnectivity();
          if (connectivity.contains(ConnectivityResult.none)) {
             await SyncService.queueMutation(data);
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved offline. Will sync when connected.')));
               Navigator.of(context).pop();
             }
             return;
          }
          
          await Supabase.instance.client.from('invoices').insert(data);
        } else {
          await Supabase.instance.client.from('invoices').update(data).eq('id', widget.invoice!.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.invoice == null ? 'Invoice created' : 'Invoice updated'),
          ));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.invoice == null ? 'Create New Invoice' : 'Edit Invoice'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoadingData)
                  const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedContractId,
                    decoration: const InputDecoration(labelText: 'Contract', border: OutlineInputBorder()),
                    items: _contracts.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(c['contract_title'] as String),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedContractId = val;
                        _selectedPhaseId = null; // Reset phase when contract changes
                      });
                    },
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPhaseId,
                    decoration: const InputDecoration(labelText: 'Payment Phase', border: OutlineInputBorder()),
                    items: _phases.where((p) => p['contract_id'] == _selectedContractId).map((p) => DropdownMenuItem<String>(
                      value: p['id'] as String,
                      child: Text(p['phase_name'] as String),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedPhaseId = val);
                    },
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  value: _invoiceType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'payable', child: Text('Bill to Pay (Vendor)')),
                    DropdownMenuItem(value: 'receivable', child: Text('Invoice to Collect (Client)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _invoiceType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vendorController,
                  decoration: const InputDecoration(labelText: 'Client / Vendor Name', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount (DZD)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final numValue = double.tryParse(value);
                    if (numValue == null) return 'Invalid number';
                    if (numValue <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _invoiceDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _invoiceDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Invoice Date', border: OutlineInputBorder()),
                          child: Text("${_invoiceDate.day}/${_invoiceDate.month}/${_invoiceDate.year}"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _dueDate = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder()),
                          child: Text("${_dueDate.day}/${_dueDate.month}/${_dueDate.year}"),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_documentUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.attachment, color: Colors.green),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Receipt Attached', style: TextStyle(color: Colors.green))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _documentUrl = null)),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OcrScanPage()),
                    );
                    if (result != null && result is Map) {
                      setState(() => _isLoading = true);
                      try {
                        final text = result['text'] as String;
                        final imagePath = result['imagePath'] as String;
                        
                        // Parse amounts and name
                        final match = RegExp(r'\d+\.\d{2}').firstMatch(text);
                        if (match != null) _amountController.text = match.group(0)!;
                        final lines = text.split('\n');
                        if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
                          _vendorController.text = lines.first.trim();
                        }
                        
                        // Upload image
                        final file = File(imagePath);
                        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                        await Supabase.instance.client.storage.from('receipts').upload(fileName, file);
                        final url = Supabase.instance.client.storage.from('receipts').getPublicUrl(fileName);
                        
                        if (mounted) {
                          setState(() {
                            _documentUrl = url;
                          });
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.invoice == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
