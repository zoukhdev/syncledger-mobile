import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  List<_SearchResult> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _controller.text.trim();
    if (q == _query) return;
    setState(() => _query = q);
    if (q.length >= 2) {
      _search(q);
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String q) async {
    setState(() => _isLoading = true);
    try {
      final results = <_SearchResult>[];
      final pattern = '%$q%';

      // Search invoices
      final invoices = await Supabase.instance.client
          .from('invoices')
          .select('id, vendor_name, amount, status, invoice_type')
          .ilike('vendor_name', pattern)
          .limit(5);
      for (final r in invoices) {
        results.add(_SearchResult(
          type: 'Invoice',
          icon: Icons.receipt_long_rounded,
          title: r['vendor_name'] as String? ?? '—',
          subtitle: '${(r['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'} DZD • ${r['status'] ?? ''}',
          id: r['id'] as String? ?? '',
        ));
      }

      // Search vendors
      final vendors = await Supabase.instance.client
          .from('vendors')
          .select('id, name, phone')
          .ilike('name', pattern)
          .limit(5);
      for (final r in vendors) {
        results.add(_SearchResult(
          type: 'Vendor',
          icon: Icons.store_rounded,
          title: r['name'] as String? ?? '—',
          subtitle: r['phone'] as String? ?? 'No phone',
          id: r['id'] as String? ?? '',
        ));
      }

      // Search clients
      final clients = await Supabase.instance.client
          .from('clients')
          .select('id, name, phone')
          .ilike('name', pattern)
          .limit(5);
      for (final r in clients) {
        results.add(_SearchResult(
          type: 'Client',
          icon: Icons.person_rounded,
          title: r['name'] as String? ?? '—',
          subtitle: r['phone'] as String? ?? 'No phone',
          id: r['id'] as String? ?? '',
        ));
      }

      // Search contracts
      final contracts = await Supabase.instance.client
          .from('contracts')
          .select('id, contract_title, status')
          .ilike('contract_title', pattern)
          .limit(5);
      for (final r in contracts) {
        results.add(_SearchResult(
          type: 'Contract',
          icon: Icons.handshake_rounded,
          title: r['contract_title'] as String? ?? '—',
          subtitle: r['status'] as String? ?? '',
          id: r['id'] as String? ?? '',
        ));
      }

      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _typeColor(String type, ColorScheme cs) {
    switch (type) {
      case 'Invoice': return cs.primary;
      case 'Vendor': return cs.secondary;
      case 'Client': return cs.tertiary;
      case 'Contract': return const Color(0xFF6A1B9A);
      default: return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search invoices, vendors, clients…',
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(color: cs.onSurface, fontSize: 16),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: cs.onSurfaceVariant),
              onPressed: () {
                _controller.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _query.length < 2
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, size: 56, color: cs.onSurfaceVariant.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Type at least 2 characters to search',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  )
                : _results.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: cs.onSurfaceVariant.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('No results for "$_query"',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          final color = _typeColor(r.type, cs);
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(r.icon, color: color, size: 22),
                            ),
                            title: Text(r.title,
                                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                            subtitle: Text(r.subtitle,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(r.type,
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            onTap: () {
                              // Navigate based on type
                              if (r.type == 'Invoice') {
                                Navigator.pop(context);
                                // Could navigate to invoice detail if needed
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String type;
  final IconData icon;
  final String title;
  final String subtitle;
  final String id;
  const _SearchResult({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.id,
  });
}
