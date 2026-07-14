import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'directory_list_view.dart';

class NewContractorDialog extends ConsumerStatefulWidget {
  final String? title;
  final String table;

  const NewContractorDialog({super.key, this.title, this.table = 'contractors'});

  @override
  ConsumerState<NewContractorDialog> createState() => _NewContractorDialogState();
}

class _NewContractorDialogState extends ConsumerState<NewContractorDialog> {
  final _formKey = GlobalKey<FormState>();
  String _companyName = '';
  String _contactName = '';
  String _email = '';
  String _phone = '';
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from(widget.table).insert({
        'company_name': _companyName,
        'contact_name': _contactName.isEmpty ? null : _contactName,
        'email': _email.isEmpty ? null : _email,
        'phone': _phone.isEmpty ? null : _phone,
      });
      
      // Invalidate the provider to refresh the list
      ref.invalidate(directoryProvider(widget.table));
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title ?? t?.addContractor ?? 'Add Contractor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: t?.companyName ?? 'Company Name',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                onSaved: (val) => _companyName = val ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: t?.contactName ?? 'Contact Name',
                  border: const OutlineInputBorder(),
                ),
                onSaved: (val) => _contactName = val ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: t?.email ?? 'Email',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                onSaved: (val) => _email = val ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: t?.phone ?? 'Phone Number',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onSaved: (val) => _phone = val ?? '',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(t?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t?.save ?? 'Save'),
        ),
      ],
    );
  }
}
