import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/models/invoice_model.dart';
import '../../../scanner/presentation/pages/ocr_scan_page.dart';
import '../../../../core/sync/sync_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  
  num _tvaRate = 19;
  String _paymentMethod = 'bank_transfer';
  
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
          'tva_rate': _tvaRate,
          'tva_amount': double.parse(_amountController.text) * (_tvaRate / 100),
          'payment_method': _paymentMethod,
          'timbre_fiscal': (_paymentMethod == 'cash' && double.parse(_amountController.text) > 100000) 
              ? (double.parse(_amountController.text) * 0.01).clamp(0, 10000) 
              : 0,
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

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF737784)),
      filled: true,
      fillColor: const Color(0xFFF5F3F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF094CB2), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      title: Text(
        widget.invoice == null ? (t?.createNewInvoice ?? 'Create New Invoice') : (t?.editInvoice ?? 'Edit Invoice'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF1B1C1D), letterSpacing: -0.5),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoadingData)
                  const Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator()))
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedContractId,
                    decoration: _buildInputDecoration(t?.contract ?? 'Contract'),
                    icon: const Icon(Icons.expand_more, color: Color(0xFF737784)),
                    items: _contracts.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(c['contract_title'] as String, overflow: TextOverflow.ellipsis),
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
                    decoration: _buildInputDecoration(t?.paymentPhase ?? 'Payment Phase'),
                    icon: const Icon(Icons.expand_more, color: Color(0xFF737784)),
                    items: _phases.where((p) => p['contract_id'] == _selectedContractId).map((p) => DropdownMenuItem<String>(
                      value: p['id'] as String,
                      child: Text(p['phase_name'] as String, overflow: TextOverflow.ellipsis),
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
                  decoration: _buildInputDecoration(t?.type ?? 'Type'),
                  icon: const Icon(Icons.expand_more, color: Color(0xFF737784)),
                  items: [
                    DropdownMenuItem(value: 'payable', child: Text(t?.billToPay ?? 'Bill to Pay (Vendor)')),
                    DropdownMenuItem(value: 'receivable', child: Text(t?.invoiceToCollect ?? 'Invoice to Collect (Client)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _invoiceType = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vendorController,
                  decoration: _buildInputDecoration('${t?.vendorClientName ?? 'Vendor / Client Name'} *'),
                  style: const TextStyle(color: Color(0xFF1B1C1D), fontWeight: FontWeight.w500),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: _buildInputDecoration('${t?.amount ?? 'Amount'} *'),
                  style: const TextStyle(color: Color(0xFF1B1C1D), fontWeight: FontWeight.w500),
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
                      child: DropdownButtonFormField<num>(
                        value: _tvaRate,
                        decoration: _buildInputDecoration(t?.tvaRate ?? 'TVA Rate (%)'),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF737784)),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('0%')),
                          DropdownMenuItem(value: 9, child: Text('9%')),
                          DropdownMenuItem(value: 19, child: Text('19%')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _tvaRate = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        isExpanded: true,
                        decoration: _buildInputDecoration(t?.paymentMethod ?? 'Payment Method'),
                        icon: const Icon(Icons.expand_more, color: Color(0xFF737784)),
                        items: [
                          DropdownMenuItem(value: 'bank_transfer', child: Text(t?.bankTransfer ?? 'Bank Transfer', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'cheque', child: Text(t?.cheque ?? 'Cheque', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'cash', child: Text(t?.cash ?? 'Cash', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'baridimob', child: Text('BaridiMob', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'wimpay', child: Text('Wimpay', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                  ],
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
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _buildInputDecoration('Invoice Date'),
                          child: Text("${_invoiceDate.day}/${_invoiceDate.month}/${_invoiceDate.year}", style: const TextStyle(color: Color(0xFF1B1C1D), fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _buildInputDecoration('Due Date'),
                          child: Text("${_dueDate.day}/${_dueDate.month}/${_dueDate.year}", style: const TextStyle(color: Color(0xFF1B1C1D), fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_documentUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Receipt Attached successfully', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13))),
                          InkWell(
                            onTap: () => setState(() => _documentUrl = null),
                            child: const Icon(Icons.close, color: Colors.green, size: 18),
                          ),
                        ],
                      ),
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
                        final urlRes = await Supabase.instance.client.storage.from('receipts').createSignedUrl(fileName, 3600);
                        
                        if (mounted) {
                          setState(() {
                            _documentUrl = urlRes;
                          });
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.document_scanner, size: 18),
                  label: const Text('Scan Receipt', style: TextStyle(fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF094CB2),
                    side: const BorderSide(color: Color(0xFF094CB2), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF434653),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B1C1D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : Text(widget.invoice == null ? 'Create' : 'Save', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
