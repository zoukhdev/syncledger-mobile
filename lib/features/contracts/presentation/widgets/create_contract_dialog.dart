import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/contracts_provider.dart';
import '../../providers/contractors_provider.dart';

class CreateContractDialog extends ConsumerStatefulWidget {
  const CreateContractDialog({super.key});

  @override
  ConsumerState<CreateContractDialog> createState() => _CreateContractDialogState();
}

class _CreateContractDialogState extends ConsumerState<CreateContractDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedContractorId;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a contractor')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('contracts').insert({
        'contract_title': _titleController.text.trim(),
        'contractor_id': _selectedContractorId,
        'total_amount': double.parse(_amountController.text.trim()),
        'status': 'active', // default status
      });

      if (!mounted) return;
      ref.invalidate(contractsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract created successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contractorsState = ref.watch(contractorsProvider);

    return AlertDialog(
      title: const Text('Create New Contract'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Contract Title', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              contractorsState.when(
                data: (contractors) {
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Contractor', border: OutlineInputBorder()),
                    value: _selectedContractorId,
                    items: contractors.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'] as String,
                        child: Text(c['company_name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedContractorId = val;
                      });
                    },
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading contractors: $err'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Total Amount (DZD)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter an amount';
                  if (double.tryParse(val) == null) return 'Must be a valid number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
        ),
      ],
    );
  }
}
