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

  Widget _buildTextField(String label, IconData icon, {TextInputType? keyboardType, bool required = false, void Function(String?)? onSaved}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0052CC), width: 2),
        ),
      ),
      keyboardType: keyboardType,
      validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
      onSaved: onSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isVendor = widget.table == 'vendors';
    final defaultTitle = isVendor ? (t?.addVendor ?? 'Add Vendor') : (t?.addContractor ?? 'Add Contractor');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle for the bottom sheet
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title ?? defaultTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              t?.companyName ?? 'Company Name',
              Icons.business_outlined,
              required: true,
              onSaved: (val) => _companyName = val ?? '',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              t?.contactName ?? 'Contact Name',
              Icons.person_outline,
              onSaved: (val) => _contactName = val ?? '',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              t?.email ?? 'Email Address',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onSaved: (val) => _email = val ?? '',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              t?.phone ?? 'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onSaved: (val) => _phone = val ?? '',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(t?.cancel ?? "Cancel", style: const TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t?.save ?? "Save", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
