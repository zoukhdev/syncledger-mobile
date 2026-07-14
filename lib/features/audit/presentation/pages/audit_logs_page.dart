import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final auditProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('audit_logs')
      .select('*, profiles:user_id(full_name)')
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res);
});

class AuditLogsPage extends ConsumerWidget {
  const AuditLogsPage({super.key});

  IconData _getIconForAction(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('update')) return Icons.edit_document;
    if (lowerAction.contains('insert') || lowerAction.contains('create')) return Icons.add_circle_outline;
    if (lowerAction.contains('delete')) return Icons.delete_outline;
    if (lowerAction.contains('login') || lowerAction.contains('auth')) return Icons.admin_panel_settings;
    return Icons.history;
  }

  Color _getIconColorForAction(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('update')) return const Color(0xFF094CB2); // Primary
    if (lowerAction.contains('insert') || lowerAction.contains('create')) return Colors.green;
    if (lowerAction.contains('delete')) return const Color(0xFFBA1A1A); // Error
    if (lowerAction.contains('auth')) return const Color(0xFF6D5E00); // Tertiary
    return const Color(0xFF434653);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(auditProvider);
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF434653)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audit Logs',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
            color: Color(0xFF1B1C1D),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF434653)),
            onPressed: () {},
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (logs) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // Filter / Sorting Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentMonth,
                    style: const TextStyle(
                      fontFamily: 'Public Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: Color(0xFF434653), // text-on-surface-variant
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    child: Row(
                      children: const [
                        Text(
                          'Filter',
                          style: TextStyle(
                            fontFamily: 'Public Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF094CB2), // text-primary
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.filter_list, size: 16, color: Color(0xFF094CB2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Log Items
            if (logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No audit logs found.', style: TextStyle(color: Color(0xFF434653))),
                ),
              )
            else
              ...logs.map((log) {
                final profile = log['profiles'];
                final userName = profile != null ? profile['full_name'] : 'System Automated';
                final action = log['action'] ?? 'UNKNOWN';
                final resource = log['resource_type'] ?? 'Record';
                final isDelete = action.toString().toLowerCase().contains('delete');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)), // outline-variant/15
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Optional Accent left border for critical actions (like Delete)
                        if (isDelete)
                          Container(
                            width: 4,
                            color: const Color(0xFFBA1A1A), // Error color
                          ),
                        
                        // Card Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Circle
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE3E2E3), // surface-container-highest
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getIconForAction(action),
                                    color: _getIconColorForAction(action),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$action - $resource',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1B1C1D),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'By $userName',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1B1C1D), // text-on-surface
                                            ),
                                          ),
                                          const Text(
                                            '•',
                                            style: TextStyle(
                                              color: Color(0xFFC3C6D5), // outline-variant
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(log['created_at']).toLocal()),
                                            style: const TextStyle(
                                              fontFamily: 'Public Sans',
                                              fontSize: 13,
                                              color: Color(0xFF434653), // text-on-surface-variant
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

            // Load More CTA
            if (logs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E8E9), // surface-container-high
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Load Earlier Logs',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF094CB2), // text-primary
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.expand_more, size: 20, color: Color(0xFF094CB2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
