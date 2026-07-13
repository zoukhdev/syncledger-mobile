import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../domain/models/po_line_item_model.dart';
import '../providers/purchase_orders_provider.dart';
import '../../../scanner/presentation/pages/ocr_scan_page.dart';

class NewPurchaseOrderDialog extends ConsumerStatefulWidget {
  const NewPurchaseOrderDialog({super.key});

  @override
  ConsumerState<NewPurchaseOrderDialog> createState() => _NewPurchaseOrderDialogState();
}

class _NewPurchaseOrderDialogState extends ConsumerState<NewPurchaseOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _poNumberController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _issuedAt = DateTime.now();
  DateTime? _expectedDelivery;
  
  List<POLineItemModel> _lineItems = [
    POLineItemModel(id: DateTime.now().toString(), poId: '', description: '', quantity: 1, unitPrice: 0)
  ];
  
  bool _isLoading = false;

  void _addLineItem() {
    setState(() {
      _lineItems.add(POLineItemModel(
        id: DateTime.now().toString(), 
        poId: '', 
        description: '', 
        quantity: 1, 
        unitPrice: 0
      ));
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      setState(() {
        _lineItems.removeAt(index);
      });
    }
  }

  void _updateLineItem(int index, POLineItemModel newItem) {
    setState(() {
      _lineItems[index] = newItem;
    });
  }

  Future<void> _scanBarcode(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OcrScanPage()),
    );
    
    if (result != null && result is Map) {
      final text = result['text'] as String;
      // Extract the first non-empty line as description
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty) {
        final currentItem = _lineItems[index];
        _updateLineItem(index, POLineItemModel(
          id: currentItem.id,
          poId: currentItem.poId,
          description: lines.first,
          quantity: currentItem.quantity,
          unitPrice: currentItem.unitPrice,
        ));
      }
    }
  }

  double get _totalAmount => _lineItems.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineItems.isEmpty || _lineItems.any((i) => (i.description?.isEmpty ?? true))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add valid line items')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create PO
      final poResponse = await Supabase.instance.client.from('purchase_orders').insert({
        'po_number': _poNumberController.text,
        'status': 'draft',
        'issued_at': _issuedAt.toIso8601String().split('T')[0],
        'expected_delivery': _expectedDelivery?.toIso8601String().split('T')[0],
        'notes': _notesController.text,
        'total_amount': _totalAmount,
      }).select().single();

      final poId = poResponse['id'];

      // Create Line Items
      final lineItemsData = _lineItems.map((item) => {
        'po_id': poId,
        'description': item.description,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      }).toList();

      await Supabase.instance.client.from('po_line_items').insert(lineItemsData);

      if (mounted) {
        ref.invalidate(purchaseOrdersProvider);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Order created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _poNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(l10n.newPurchaseOrder, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _poNumberController,
                              decoration: InputDecoration(labelText: '${l10n.poNumber} *', border: const OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _issuedAt,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) setState(() => _issuedAt = date);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(labelText: l10n.issueDate, border: const OutlineInputBorder()),
                                child: Text("${_issuedAt.day}/${_issuedAt.month}/${_issuedAt.year}"),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.lineItems, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._lineItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.description,
                                        decoration: InputDecoration(labelText: l10n.itemDescription, border: const OutlineInputBorder()),
                                        onChanged: (val) => _updateLineItem(index, POLineItemModel(
                                          id: item.id, poId: item.poId, description: val, quantity: item.quantity, unitPrice: item.unitPrice
                                        )),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      tooltip: 'Scan Barcode / Text',
                                      onPressed: () => _scanBarcode(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.quantity.toString(),
                                        decoration: InputDecoration(labelText: l10n.qty, border: const OutlineInputBorder()),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) => _updateLineItem(index, POLineItemModel(
                                          id: item.id, poId: item.poId, description: item.description, 
                                          quantity: double.tryParse(val) ?? 0, unitPrice: item.unitPrice
                                        )),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.unitPrice.toString(),
                                        decoration: InputDecoration(labelText: l10n.unitPrice, border: const OutlineInputBorder()),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (val) => _updateLineItem(index, POLineItemModel(
                                          id: item.id, poId: item.poId, description: item.description, 
                                          quantity: item.quantity, unitPrice: double.tryParse(val) ?? 0
                                        )),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: _lineItems.length > 1 ? () => _removeLineItem(index) : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addItem),
                        onPressed: _addLineItem,
                      ),
                      const SizedBox(height: 16),
                      Text('${l10n.totalAmount}: ${_totalAmount.toStringAsFixed(2)} DA', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(labelText: l10n.notes, border: const OutlineInputBorder()),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading ? const CircularProgressIndicator() : Text(l10n.createPO),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
