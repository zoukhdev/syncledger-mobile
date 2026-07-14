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

class StaffPage extends ConsumerStatefulWidget {
  const StaffPage({super.key});

  @override
  ConsumerState<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<StaffPage> {
  String _selectedFilter = 'All Staff';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffState = ref.watch(staffProvider);
    final authState = ref.watch(authProvider);
    final isOwner = authState.value?.role == 'owner';
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: Text(
          t?.staffDirectory ?? 'Staff Directory',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF111827)),
            onPressed: () {}, // Searching is implemented inline below
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0F172A),
              shape: const CircleBorder(),
              onPressed: () => _showAddStaffDialog(context, ref),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('All Staff'),
                const SizedBox(width: 8),
                _buildFilterChip('Active'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending'),
              ],
            ),
          ),
          
          Expanded(
            child: staffState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text(t?.errorPrefix(err.toString()) ?? 'Error: $err')),
              data: (staffList) {
                // Filter logic
                final filteredStaff = staffList.where((staff) {
                  // Search query filter
                  final name = (staff['full_name'] as String?)?.toLowerCase() ?? '';
                  if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  // Status filter
                  final isPending = staff['force_password_reset'] == true;
                  if (_selectedFilter == 'Active' && isPending) return false;
                  if (_selectedFilter == 'Pending' && !isPending) return false;
                  
                  return true;
                }).toList();

                if (filteredStaff.isEmpty) {
                  return const Center(child: Text('No staff members found.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredStaff.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index];
                    return StaffMemberCard(
                      staff: staff,
                      isOwner: isOwner,
                      onRefresh: () => ref.refresh(staffProvider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF6B7280),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade300,
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
        return StatefulBuilder(builder: (context, setState) {
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
                onPressed: isLoading
                    ? null
                    : () async {
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
        });
      },
    );
  }
}

class StaffMemberCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final bool isOwner;
  final VoidCallback onRefresh;

  const StaffMemberCard({
    super.key,
    required this.staff,
    required this.isOwner,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isPending = staff['force_password_reset'] == true;
    
    // Status Badge Colors
    final statusBg = isPending ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7);
    final statusText = isPending ? const Color(0xFF9A3412) : const Color(0xFF15803D);
    final statusLabel = isPending ? (t?.pendingPassword ?? 'PENDING') : (t?.active ?? 'ACTIVE');

    // Default Initials for Avatar
    final name = staff['full_name'] as String? ?? 'Unknown';
    String initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        staff['role'] == 'admin' ? 'Admin' : (staff['role'] == 'owner' ? 'Owner' : 'Staff'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                      onSelected: (val) async {
                        try {
                          if (val == 'reset') {
                            await Supabase.instance.client.functions.invoke('reset-staff-password', body: {'userId': staff['id']});
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
                          } else if (val == 'remove') {
                            await Supabase.instance.client.functions.invoke('delete-staff', body: {'userId': staff['id']});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff removed')));
                              onRefresh();
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
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 32, color: Color(0xFFF3F4F6), thickness: 1),
            Row(
              children: [
                Expanded(child: _buildStat('INVOICES', staff['invoices_count'] ?? 0)),
                Container(width: 1, height: 32, color: const Color(0xFFF3F4F6)),
                Expanded(child: _buildStat('PAYMENTS', staff['payments_count'] ?? 0)),
                Container(width: 1, height: 32, color: const Color(0xFFF3F4F6)),
                Expanded(child: _buildStat('DOCS', staff['documents_count'] ?? 0)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
