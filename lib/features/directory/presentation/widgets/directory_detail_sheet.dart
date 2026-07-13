import 'package:flutter/material.dart';
import 'directory_list_view.dart';
import '../../../invoices/presentation/widgets/status_badge.dart';
import '../../../documents/presentation/widgets/documents_section.dart';

class DirectoryDetailSheet extends StatefulWidget {
  final DirectoryEntity entity;
  const DirectoryDetailSheet({super.key, required this.entity});

  @override
  State<DirectoryDetailSheet> createState() => _DirectoryDetailSheetState();
}

class _DirectoryDetailSheetState extends State<DirectoryDetailSheet> {
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = widget.entity.invoices.where((inv) {
      final matchesSearch = _searchQuery.isEmpty || 
          inv.status.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          inv.amount.toString().contains(_searchQuery);

      final invDate = inv.date;
      final afterStart = _startDate == null || invDate.isAfter(_startDate!) || invDate.isAtSameMomentAs(_startDate!);
      final beforeEnd = _endDate == null || invDate.isBefore(_endDate!.add(const Duration(days: 1)));

      return matchesSearch && afterStart && beforeEnd;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.entity.name, style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 8),
                      Text('Total Value: ${widget.entity.totalSpend.toStringAsFixed(2)} DZD', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          // Tabs
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Invoices'),
                      Tab(text: 'Documents'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Invoices Tab
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Search (Status or Amount)',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (v) => setState(() => _searchQuery = v),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.date_range),
                                          label: Text(_startDate == null ? 'Start Date' : "\${_startDate!.day}/\${_startDate!.month}/\${_startDate!.year}"),
                                          onPressed: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: _startDate ?? DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (d != null) setState(() => _startDate = d);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.date_range),
                                          label: Text(_endDate == null ? 'End Date' : "\${_endDate!.day}/\${_endDate!.month}/\${_endDate!.year}"),
                                          onPressed: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: _endDate ?? DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (d != null) setState(() => _endDate = d);
                                          },
                                        ),
                                      ),
                                      if (_startDate != null || _endDate != null)
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setState(() { _startDate = null; _endDate = null; }),
                                        )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredInvoices.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final inv = filteredInvoices[index];
                                  return ListTile(
                                    title: Text('Invoice #\${inv.id.substring(0, 8)}'),
                                    subtitle: Text("\${inv.date.day}/\${inv.date.month}/\${inv.date.year}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusBadge(status: inv.status),
                                        const SizedBox(width: 16),
                                        Text('\${inv.amount.toStringAsFixed(2)} DZD', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        // Documents Tab
                        DocumentsSection(entityId: widget.entity.id, entityType: 'contractor'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
