import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class AuditState {
  final List<Map<String, dynamic>> logs;
  final bool isLoadingMore;
  final bool hasMore;
  const AuditState({required this.logs, this.isLoadingMore = false, this.hasMore = true});
  AuditState copyWith({List<Map<String, dynamic>>? logs, bool? isLoadingMore, bool? hasMore}) =>
      AuditState(
          logs: logs ?? this.logs,
          isLoadingMore: isLoadingMore ?? this.isLoadingMore,
          hasMore: hasMore ?? this.hasMore);
}

class AuditNotifier extends StateNotifier<AsyncValue<AuditState>> {
  AuditNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }
  static const int _pageSize = 20;

  Future<void> fetch({int offset = 0}) async {
    if (offset == 0) state = const AsyncValue.loading();
    try {
      // Fetch audit logs with profile join + invoice details join
      final res = await Supabase.instance.client
          .from('audit_logs')
          .select('''
            *,
            profiles:user_id ( full_name ),
            invoices:invoice_id (
              vendor_name,
              amount,
              invoice_type,
              status
            )
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final fetched = List<Map<String, dynamic>>.from(res);
      final prev = state.valueOrNull?.logs ?? [];
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

final auditProvider =
    StateNotifierProvider<AuditNotifier, AsyncValue<AuditState>>((ref) => AuditNotifier());

// ── Helpers ───────────────────────────────────────────────────────────────────
String _humanActionType(String? actionType) {
  switch ((actionType ?? '').toUpperCase()) {
    case 'INSERT':
      return 'Created';
    case 'UPDATE':
      return 'Updated';
    case 'DELETE':
      return 'Deleted';
    default:
      return actionType ?? 'Unknown Action';
  }
}

IconData _iconForAction(String? actionType) {
  switch ((actionType ?? '').toUpperCase()) {
    case 'INSERT':
      return Icons.add_circle_outline_rounded;
    case 'UPDATE':
      return Icons.edit_outlined;
    case 'DELETE':
      return Icons.delete_outline_rounded;
    default:
      return Icons.history_rounded;
  }
}

Color _colorForAction(String? actionType, ColorScheme cs) {
  switch ((actionType ?? '').toUpperCase()) {
    case 'INSERT':
      return cs.secondary;
    case 'UPDATE':
      return cs.primary;
    case 'DELETE':
      return cs.error;
    default:
      return cs.onSurfaceVariant;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────
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
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: -0.5,
              color: cs.onSurface),
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
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by user, action or vendor...',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // List
          Expanded(
            child: asyncState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (auditState) {
                final logs = _search.isEmpty
                    ? auditState.logs
                    : auditState.logs.where((log) {
                        final name =
                            (log['profiles']?['full_name'] ?? '').toString().toLowerCase();
                        final action =
                            (log['action_type'] ?? '').toString().toLowerCase();
                        final vendor =
                            (log['invoices']?['vendor_name'] ?? '').toString().toLowerCase();
                        final invoiceId = (log['invoice_id'] ?? '').toString().toLowerCase();
                        return name.contains(_search) ||
                            action.contains(_search) ||
                            vendor.contains(_search) ||
                            invoiceId.contains(_search);
                      }).toList();

                if (logs.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history_rounded,
                          size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
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
                      // Load more button at bottom
                      if (index == logs.length) {
                        if (!auditState.hasMore) return const SizedBox(height: 24);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: auditState.isLoadingMore
                                ? const CircularProgressIndicator()
                                : FilledButton.tonal(
                                    onPressed: () =>
                                        ref.read(auditProvider.notifier).loadMore(),
                                    style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20))),
                                    child: const Text('Load Earlier Logs'),
                                  ),
                          ),
                        );
                      }

                      final log = logs[index];
                      return _AuditCard(log: log, cs: cs);
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

// ── Audit Card ────────────────────────────────────────────────────────────────
class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final ColorScheme cs;

  const _AuditCard({required this.log, required this.cs});

  @override
  Widget build(BuildContext context) {
    // Core fields
    final actionType = log['action_type'] as String?;
    final isDelete = (actionType ?? '').toUpperCase() == 'DELETE';
    final actionColor = _colorForAction(actionType, cs);
    final actionLabel = _humanActionType(actionType);

    // User info
    final profile = log['profiles'];
    final userName = (profile != null && profile['full_name'] != null)
        ? profile['full_name'] as String
        : 'System / Automated';

    // Invoice details (joined)
    final invoiceData = log['invoices'] as Map<String, dynamic>?;
    final invoiceId = log['invoice_id'] as String?;
    final vendorName = invoiceData?['vendor_name'] as String?;
    final amount = invoiceData?['amount'];
    final invoiceType = invoiceData?['invoice_type'] as String?;
    final invoiceStatus = invoiceData?['status'] as String?;

    // Timestamp
    final createdAt = log['created_at'] != null
        ? DateFormat('dd MMM yyyy  HH:mm').format(DateTime.parse(log['created_at']).toLocal())
        : '—';

    // IP address
    final ipAddress = log['ip_address'] as String?;

    // Build detail chips
    final chips = <_DetailChip>[];

    if (vendorName != null && vendorName.isNotEmpty) {
      chips.add(_DetailChip(
        icon: Icons.store_rounded,
        label: vendorName,
        cs: cs,
        color: cs.secondary,
      ));
    }
    if (amount != null) {
      chips.add(_DetailChip(
        icon: Icons.payments_outlined,
        label: '${(amount as num).toStringAsFixed(2)} DZD',
        cs: cs,
        color: cs.primary,
      ));
    }
    if (invoiceType != null && invoiceType.isNotEmpty) {
      chips.add(_DetailChip(
        icon: Icons.label_outline_rounded,
        label: invoiceType,
        cs: cs,
        color: cs.tertiary,
      ));
    }
    if (invoiceStatus != null && invoiceStatus.isNotEmpty) {
      final statusColor = _statusColor(invoiceStatus, cs);
      chips.add(_DetailChip(
        icon: Icons.circle,
        label: _capitalise(invoiceStatus),
        cs: cs,
        color: statusColor,
        isSmallIcon: true,
      ));
    }
    if (ipAddress != null && ipAddress.isNotEmpty) {
      chips.add(_DetailChip(
        icon: Icons.router_outlined,
        label: ipAddress,
        cs: cs,
        color: cs.onSurfaceVariant,
      ));
    }

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
            // Red left bar for deletes
            if (isDelete)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: cs.error,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: actionColor.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(_iconForAction(actionType), color: actionColor, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Action label + action type badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  // Primary headline: "Created Invoice" / "Updated Invoice" etc
                                  invoiceId != null
                                      ? '$actionLabel Invoice'
                                      : actionLabel,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: actionColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  actionType ?? '—',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: actionColor,
                                      letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // By user
                          Text(
                            'By $userName',
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),

                          // Detail chips row
                          if (chips.isNotEmpty) ...[
                            Wrap(spacing: 6, runSpacing: 6, children: chips),
                            const SizedBox(height: 8),
                          ],

                          // Bottom row: timestamp + invoice ID
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            _InfoChip(icon: Icons.schedule_rounded, label: createdAt, cs: cs),
                            if (invoiceId != null && invoiceId.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: invoiceId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Invoice ID copied'),
                                        duration: Duration(seconds: 1)),
                                  );
                                },
                                child: _InfoChip(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'INV: ${invoiceId.substring(0, 8).toUpperCase()}',
                                  cs: cs,
                                  tappable: true,
                                ),
                              ),
                          ]),
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
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status.toLowerCase()) {
      case 'approved':
        return cs.secondary;
      case 'pending':
        return cs.tertiary;
      case 'rejected':
        return cs.error;
      case 'paid':
        return const Color(0xFF1B8A5A);
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Chip widgets ──────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color color;
  final bool isSmallIcon;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.color,
    this.isSmallIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: isSmallIcon ? 8 : 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool tappable;

  const _InfoChip(
      {required this.icon, required this.label, required this.cs, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    final color = tappable ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tappable ? cs.primaryContainer.withOpacity(0.35) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        if (tappable) ...[
          const SizedBox(width: 3),
          Icon(Icons.copy_rounded, size: 10, color: color),
        ],
      ]),
    );
  }
}
