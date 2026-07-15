import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// â”€â”€ Pagination state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AuditState {
  final List<Map<String, dynamic>> logs;
  final bool isLoadingMore;
  final bool hasMore;
  const AuditState({required this.logs, this.isLoadingMore = false, this.hasMore = true});
  AuditState copyWith({List<Map<String, dynamic>>? logs, bool? isLoadingMore, bool? hasMore}) =>
      AuditState(logs: logs ?? this.logs, isLoadingMore: isLoadingMore ?? this.isLoadingMore, hasMore: hasMore ?? this.hasMore);
}

class AuditNotifier extends StateNotifier<AsyncValue<AuditState>> {
  AuditNotifier() : super(const AsyncValue.loading()) { fetch(); }
  static const int _pageSize = 20;

  Future<void> fetch({int offset = 0}) async {
    if (offset == 0) state = const AsyncValue.loading();
    try {
      final res = await Supabase.instance.client
          .from('audit_logs')
          .select('*, profiles:user_id(full_name)')
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);
      final fetched = List<Map<String, dynamic>>.from(res);
      final prev = (state.valueOrNull?.logs ?? []);
      final combined = offset == 0 ? fetched : [...prev, ...fetched];
      state = AsyncValue.data(AuditState(logs: combined, hasMore: fetched.length == _pageSize));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    await fetch(offset: current.logs.length);
  }

  Future<void> refresh() => fetch();
}

final auditProvider = StateNotifierProvider<AuditNotifier, AsyncValue<AuditState>>((ref) => AuditNotifier());

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
String _humanAction(String? action, String? resource) {
  final a = (action ?? '').toUpperCase();
  final r = _humanResource(resource);
  if (a.contains('INSERT') || a.contains('CREATE')) return 'Created $r';
  if (a.contains('UPDATE')) return 'Updated $r';
  if (a.contains('DELETE')) return 'Deleted $r';
  if (a.contains('LOGIN') || a.contains('AUTH') || a.contains('SIGN')) return 'User Signed In';
  if (a.contains('APPROVE')) return 'Approved $r';
  if (a.contains('REJECT')) return 'Rejected $r';
  return '$a $r'.trim();
}

String _humanResource(String? resource) {
  if (resource == null) return '';
  switch (resource.toLowerCase()) {
    case 'invoices': return 'Invoice';
    case 'payments': return 'Payment';
    case 'contracts': return 'Contract';
    case 'payment_phases': return 'Payment Phase';
    case 'vendors': return 'Vendor';
    case 'clients': return 'Client';
    case 'profiles': return 'Profile';
    case 'staff': return 'Staff Member';
    case 'cash_registers': return 'Cash Register';
    case 'purchase_orders': return 'Purchase Order';
    default: return resource;
  }
}

IconData _iconForAction(String? action) {
  final a = (action ?? '').toUpperCase();
  if (a.contains('INSERT') || a.contains('CREATE')) return Icons.add_circle_outline;
  if (a.contains('UPDATE')) return Icons.edit_outlined;
  if (a.contains('DELETE')) return Icons.delete_outline;
  if (a.contains('LOGIN') || a.contains('AUTH') || a.contains('SIGN')) return Icons.login_rounded;
  if (a.contains('APPROVE')) return Icons.check_circle_outline;
  if (a.contains('REJECT')) return Icons.cancel_outlined;
  return Icons.history_rounded;
}

Color _colorForAction(String? action, ColorScheme cs) {
  final a = (action ?? '').toUpperCase();
  if (a.contains('INSERT') || a.contains('CREATE')) return cs.secondary;
  if (a.contains('UPDATE') || a.contains('APPROVE')) return cs.primary;
  if (a.contains('DELETE') || a.contains('REJECT')) return cs.error;
  if (a.contains('LOGIN') || a.contains('AUTH') || a.contains('SIGN')) return cs.tertiary;
  return cs.onSurfaceVariant;
}

// â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});
  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final asyncState = ref.watch(auditProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Audit Logs',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5, color: cs.onSurface),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            onPressed: () => ref.read(auditProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by user or actionâ€¦',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: asyncState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (auditState) {
                final logs = _search.isEmpty
                    ? auditState.logs
                    : auditState.logs.where((log) {
                        final name = (log['profiles']?['full_name'] ?? '').toString().toLowerCase();
                        final action = (log['action'] ?? '').toString().toLowerCase();
                        final resource = (log['resource_type'] ?? '').toString().toLowerCase();
                        return name.contains(_search) || action.contains(_search) || resource.contains(_search);
                      }).toList();

                if (logs.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No logs found', style: TextStyle(color: cs.onSurfaceVariant)),
                    ]),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(auditProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: logs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                        if (!auditState.hasMore) return const SizedBox(height: 24);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: auditState.isLoadingMore
                                ? const CircularProgressIndicator()
                                : FilledButton.tonal(
                                    onPressed: () => ref.read(auditProvider.notifier).loadMore(),
                                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                    child: const Text('Load Earlier Logs'),
                                  ),
                          ),
                        );
                      }

                      final log = logs[index];
                      final profile = log['profiles'];
                      final userName = (profile != null && profile['full_name'] != null)
                          ? profile['full_name'] as String
                          : 'System / Automated';
                      final action = log['action'] as String?;
                      final resource = log['resource_type'] as String?;
                      final resourceId = log['resource_id']?.toString();
                      final isDelete = (action ?? '').toUpperCase().contains('DELETE');
                      final actionColor = _colorForAction(action, cs);
                      final createdAt = log['created_at'] != null
                          ? DateFormat('dd MMM yyyy  HH:mm').format(DateTime.parse(log['created_at']).toLocal())
                          : 'â€”';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: isDelete ? Border.all(color: cs.error.withOpacity(0.4), width: 1.5) : null,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isDelete)
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: cs.error,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                  ),
                                ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(color: actionColor.withOpacity(0.12), shape: BoxShape.circle),
                                        child: Icon(_iconForAction(action), color: actionColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(_humanAction(action, resource),
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                          const SizedBox(height: 4),
                                          Text('By $userName',
                                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                                          const SizedBox(height: 6),
                                          Wrap(spacing: 8, runSpacing: 4, children: [
                                            _Chip(icon: Icons.schedule_rounded, label: createdAt, cs: cs),
                                            if (resourceId != null && resourceId.isNotEmpty)
                                              GestureDetector(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: resourceId));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('ID copied'), duration: Duration(seconds: 1)),
                                                  );
                                                },
                                                child: _Chip(
                                                  icon: Icons.fingerprint_rounded,
                                                  label: resourceId.length > 12 ? '${resourceId.substring(0, 12)}â€¦' : resourceId,
                                                  cs: cs,
                                                  tappable: true,
                                                ),
                                              ),
                                          ]),
                                        ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool tappable;
  const _Chip({required this.icon, required this.label, required this.cs, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tappable ? cs.primaryContainer.withOpacity(0.4) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: tappable ? cs.primary : cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: tappable ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        if (tappable) ...[const SizedBox(width: 3), Icon(Icons.copy_rounded, size: 10, color: cs.primary)],
      ]),
    );
  }
}
