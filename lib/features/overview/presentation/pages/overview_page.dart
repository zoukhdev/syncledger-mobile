import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../contracts/providers/contracts_provider.dart';

final overviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  const secureStorage = FlutterSecureStorage();
  final connectivity = await Connectivity().checkConnectivity();
  
  List invoicesRes = [];
  
  if (connectivity.contains(ConnectivityResult.none)) {
    // Offline Mode: Load from cache
    final cachedData = await secureStorage.read(key: 'cached_overview_invoices');
    if (cachedData != null) {
      invoicesRes = jsonDecode(cachedData);
    }
  } else {
    // Online Mode: Fetch from Supabase and cache
    invoicesRes = await Supabase.instance.client.from('invoices').select('amount, status, invoice_type, invoice_date');
    await secureStorage.write(key: 'cached_overview_invoices', value: jsonEncode(invoicesRes));
    
    // Clear old SharedPreferences cache if exists (Migration)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_overview_invoices');
  }
  
  double totalRevenue = 0;
  double pendingReceivables = 0;
  double pendingPayables = 0;
  
  // For the chart: Revenue by day for the last 7 days
  final Map<int, double> dailyRevenue = {};
  final now = DateTime.now();
  for (int i = 0; i < 7; i++) {
    dailyRevenue[i] = 0; // 0 is today, 1 is yesterday, etc.
  }

  for (var inv in (invoicesRes as List)) {
    final amount = (inv['amount'] as num).toDouble();
    final type = inv['invoice_type'];
    final status = inv['status'];
    final date = DateTime.tryParse(inv['invoice_date'] ?? '') ?? DateTime.now();
    
    if (type == 'receivable') {
      if (status == 'paid') {
        totalRevenue += amount;
        
        // Chart aggregation
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 7) {
          dailyRevenue[diff] = (dailyRevenue[diff] ?? 0) + amount;
        }
      }
      if (status == 'pending_approval' || status == 'pending_payment') {
        pendingReceivables += amount;
      }
    } else {
      if (status == 'pending_approval' || status == 'pending_payment') {
        pendingPayables += amount;
      }
    }
  }

  // Convert dailyRevenue to list of spots for the chart (x = day offset, y = amount)
  // Reversing so left is oldest (6 days ago), right is today (0 days ago)
  List<FlSpot> spots = [];
  for (int i = 6; i >= 0; i--) {
    spots.add(FlSpot((6 - i).toDouble(), dailyRevenue[i]!));
  }

  // Expiring documents (next 30 days)
  final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
  List expiringDocs = [];
  try {
    expiringDocs = await Supabase.instance.client
        .from('documents')
        .select('*')
        .lte('expiry_date', thirtyDaysFromNow.toIso8601String())
        .gte('expiry_date', DateTime.now().toIso8601String())
        .order('expiry_date', ascending: true);
  } catch (_) {}

  // Overdue Invoices
  List overdueInvoices = [];
  try {
    overdueInvoices = await Supabase.instance.client
        .from('invoices')
        .select('*, contractors(company_name)')
        .lt('due_date', DateTime.now().toIso8601String())
        .inFilter('status', ['pending_approval', 'pending_payment'])
        .order('due_date', ascending: true);
  } catch (_) {}

  return {
    'revenue': totalRevenue,
    'receivables': pendingReceivables,
    'payables': pendingPayables,
    'total_invoices': invoicesRes.length,
    'chart_spots': spots,
    'expiring_docs': expiringDocs,
    'overdue_invoices': overdueInvoices,
  };
});

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(overviewProvider);
    final contractsState = ref.watch(contractsProvider);
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t?.overview ?? 'Overview')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(t?.errorPrefix(err.toString()) ?? 'Error: $err')),
        data: (data) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildMetricCard(
                          context, 
                          t?.totalCollectedRevenue ?? 'Total Collected Revenue', 
                          data['revenue'], 
                          Icons.arrow_upward, 
                          const Color(0xFF4CAF50), 
                          [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)], 
                          true,
                          cardWidth,
                        ),
                        _buildMetricCard(
                          context, 
                          t?.pendingReceivables ?? 'Pending Receivables', 
                          data['receivables'], 
                          Icons.arrow_downward, 
                          const Color(0xFF2196F3), 
                          [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)], 
                          false,
                          cardWidth,
                        ),
                        _buildMetricCard(
                          context, 
                          t?.pendingPayables ?? 'Pending Payables', 
                          data['payables'], 
                          Icons.arrow_upward, 
                          const Color(0xFFFF9800), 
                          [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)], 
                          false,
                          double.infinity,
                        ),
                      ],
                    );
                  },
                ),
                if ((data['overdue_invoices'] as List).isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Overdue Invoices (${(data['overdue_invoices'] as List).length})', style: theme.textTheme.titleLarge?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (data['overdue_invoices'] as List).length,
                    itemBuilder: (context, index) {
                      final inv = data['overdue_invoices'][index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.red.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          title: Text(inv['contractors']?['company_name'] ?? 'Unknown Vendor'),
                          subtitle: Text('Due: ${inv['due_date'].split('T')[0]}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${inv['amount']} DZD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              Text(inv['status'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                ],

                const SizedBox(height: 32),
                Text(t?.revenueLast7Days ?? 'Revenue (Last 7 Days)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildChart(context, data['chart_spots']),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Contracts', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20)),
                    TextButton(
                      onPressed: () => context.push('/contracts'),
                      child: Text(t?.viewAll ?? 'View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildContractsList(context, contractsState, theme),

                if ((data['expiring_docs'] as List).isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text('Expiring Documents (30 Days)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (data['expiring_docs'] as List).length,
                    itemBuilder: (context, index) {
                      final doc = data['expiring_docs'][index];
                      final isExpired = DateTime.parse(doc['expiry_date']).isBefore(DateTime.now());
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(Icons.warning_amber_rounded, color: isExpired ? Colors.red : Colors.orange),
                          title: Text(doc['document_type'] ?? 'Document'),
                          subtitle: Text('Exp: ${doc['expiry_date'].split('T')[0]}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> spots) {
    final theme = Theme.of(context);
    
    // Calculate max Y for chart scaling
    double maxY = 100;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y * 1.2;
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // value is 0 (6 days ago) to 6 (today)
                      final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('E').format(date), style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: theme.colorScheme.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.3),
                        theme.colorScheme.primary.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, double value, IconData icon, Color iconColor, List<Color> gradientColors, bool isRevenue, [double? width]) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${value.toStringAsFixed(2)} DZD', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(isRevenue ? Icons.attach_money : Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContractsList(BuildContext context, AsyncValue contractsState, ThemeData theme) {
    final t = AppLocalizations.of(context);
    return contractsState.when(
      data: (contracts) {
        if (contracts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(t?.noActiveContracts ?? 'No active contracts found.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contracts.length > 5 ? 5 : contracts.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final contract = contracts[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: RichText(
                text: TextSpan(
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  children: [
                    TextSpan(text: '${contract.contractTitle} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: '• ${contract.contractorName ?? (t?.unknownVendor ?? 'Unknown')} • '),
                    TextSpan(text: '${contract.totalAmount.toStringAsFixed(2)} DZD'),
                  ],
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onTap: () {
                context.push('/contracts');
              },
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $error'),
      ),
    );
  }
}
