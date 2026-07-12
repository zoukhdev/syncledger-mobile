import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../contracts/providers/contracts_provider.dart';

final overviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final connectivity = await Connectivity().checkConnectivity();
  
  List invoicesRes = [];
  
  if (connectivity.contains(ConnectivityResult.none)) {
    // Offline Mode: Load from cache
    final cachedData = prefs.getString('cached_overview_invoices');
    if (cachedData != null) {
      invoicesRes = jsonDecode(cachedData);
    }
  } else {
    // Online Mode: Fetch from Supabase and cache
    invoicesRes = await Supabase.instance.client.from('invoices').select('amount, status, invoice_type, invoice_date');
    await prefs.setString('cached_overview_invoices', jsonEncode(invoicesRes));
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

  return {
    'revenue': totalRevenue,
    'receivables': pendingReceivables,
    'payables': pendingPayables,
    'total_invoices': invoicesRes.length,
    'chart_spots': spots,
  };
});

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(overviewProvider);
    final contractsState = ref.watch(contractsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
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
                        _buildMetricCard(context, 'Total Collected Revenue', data['revenue'], Icons.attach_money, Colors.green, cardWidth),
                        _buildMetricCard(context, 'Pending Receivables', data['receivables'], Icons.arrow_downward, Colors.blue, cardWidth),
                        _buildMetricCard(context, 'Pending Payables', data['payables'], Icons.arrow_upward, Colors.orange, cardWidth),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text('Revenue (Last 7 Days)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildChart(context, data['chart_spots']),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Contracts', style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.push('/contracts'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildContractsList(context, contractsState, theme),
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
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, double value, IconData icon, Color color, [double? width]) {
    return SizedBox(
      width: width,
      child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title, 
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${value.toStringAsFixed(2)} DZD', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildContractsList(BuildContext context, AsyncValue contractsState, ThemeData theme) {
    return contractsState.when(
      data: (contracts) {
        if (contracts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No active contracts found.'),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: contracts.length > 5 ? 5 : contracts.length,
          itemBuilder: (context, index) {
            final contract = contracts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(contract.contractTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${contract.contractorName ?? 'Unknown Vendor'} • ${contract.totalAmount.toStringAsFixed(2)} DZD',
                    style: TextStyle(color: theme.colorScheme.primary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/contracts');
                },
              ),
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
