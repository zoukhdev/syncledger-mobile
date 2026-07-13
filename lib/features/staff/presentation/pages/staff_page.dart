import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';

final staffProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  
  final res = await supabase.from('profiles').select();
  final staffList = List<Map<String, dynamic>>.from(res);

  // Fetch productivity
  final invoicesRes = await supabase.from('invoices').select('id, created_by');
  final paymentsRes = await supabase.from('payments').select('id, created_by');
  final documentsRes = await supabase.from('documents').select('id, uploaded_by');

  for (var staff in staffList) {
    staff['invoices_count'] = 0;
    staff['payments_count'] = 0;
    staff['documents_count'] = 0;
  }

  for (var inv in (invoicesRes as List)) {
    final userId = inv['created_by'];
    if (userId != null) {
      final staff = staffList.firstWhere((s) => s['id'] == userId, orElse: () => {});
      if (staff.isNotEmpty) staff['invoices_count'] = (staff['invoices_count'] ?? 0) + 1;
    }
  }

  for (var pay in (paymentsRes as List)) {
    final userId = pay['created_by'];
    if (userId != null) {
      final staff = staffList.firstWhere((s) => s['id'] == userId, orElse: () => {});
      if (staff.isNotEmpty) staff['payments_count'] = (staff['payments_count'] ?? 0) + 1;
    }
  }

  for (var doc in (documentsRes as List)) {
    final userId = doc['uploaded_by'];
    if (userId != null) {
      final staff = staffList.firstWhere((s) => s['id'] == userId, orElse: () => {});
      if (staff.isNotEmpty) staff['documents_count'] = (staff['documents_count'] ?? 0) + 1;
    }
  }

  return staffList;
});

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffState = ref.watch(staffProvider);
    final authState = ref.watch(authProvider);
    final isOwner = authState.value?.role == 'owner';
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t?.staffDirectory ?? 'Staff Directory')),
      floatingActionButton: isOwner ? FloatingActionButton(
        onPressed: () => _showAddStaffDialog(context, ref),
        child: const Icon(Icons.person_add),
      ) : null,
      body: staffState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(t?.errorPrefix(err.toString()) ?? 'Error: $err')),
        data: (staffList) => ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(staff['full_name'] ?? (t?.unknownUser ?? 'Unknown User'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(staff['role'] ?? 'staff', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        staff['force_password_reset'] == true 
                            ? Chip(label: Text(t?.pendingPassword ?? 'Pending', style: const TextStyle(fontSize: 10)), backgroundColor: Colors.orange) 
                            : Chip(label: Text(t?.active ?? 'Active', style: const TextStyle(fontSize: 10)), backgroundColor: Colors.green),
                        if (isOwner)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (val) async {
                              try {
                                if (val == 'reset') {
                                  await Supabase.instance.client.functions.invoke('reset-staff-password', body: {'userId': staff['id']});
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
                                } else if (val == 'remove') {
                                  await Supabase.instance.client.functions.invoke('delete-staff', body: {'userId': staff['id']});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff removed')));
                                    ref.refresh(staffProvider);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'reset', child: Text('Resend Password Reset')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove Staff')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Invoices', staff['invoices_count']),
                        _buildStat('Payments', staff['payments_count']),
                        _buildStat('Docs', staff['documents_count']),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final roleController = TextEditingController(text: 'staff');

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Staff'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: roleController.text,
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (val) => roleController.text = val ?? 'staff',
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (emailController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await Supabase.instance.client.functions.invoke('create-staff', body: {
                        'email': emailController.text,
                        'fullName': nameController.text,
                        'role': roleController.text,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ref.refresh(staffProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
