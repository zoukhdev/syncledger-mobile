import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/analytics_provider.dart';
import '../../utils/pdf_report_generator.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () {
              final data = ref.read(analyticsProvider).valueOrNull;
              if (data != null) {
                PdfReportGenerator.generateAndShareMonthlyReport(data, l10n);
              }
            },
          ),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Cards
                Row(
                  children: [
                    Expanded(child: _KPICard(title: l10n.revenue, amount: data.totalRevenue, color: Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _KPICard(title: l10n.expense, amount: data.totalExpenses, color: Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _KPICard(title: l10n.netProfit, amount: data.netProfit, color: data.netProfit >= 0 ? Colors.blue : Colors.red)),
                  ],
                ),
                const SizedBox(height: 24),
                
                // P&L Chart
                Text(l10n.pnlTrend, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: [data.totalRevenue, data.totalExpenses, 1000.0].reduce((a, b) => a > b ? a : b) / 3, // rough scale
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (value < 0 || value >= data.pnlData.length) return const Text('');
                                  return Text(data.pnlData[value.toInt()]['month']);
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: data.pnlData.asMap().entries.map((e) {
                            final i = e.key;
                            final rev = e.value['revenue'] as double;
                            final exp = e.value['expenses'] as double;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(toY: rev, color: Colors.green, width: 12),
                                BarChartRodData(toY: exp, color: Colors.red, width: 12),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // Top Vendors Pie Chart
                Text(l10n.topVendors, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: data.spendData.isEmpty 
                        ? Center(child: Text(l10n.noExpenseData))
                        : PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: data.spendData.asMap().entries.map((e) {
                                final i = e.key;
                                final val = e.value['value'] as double;
                                final colors = [Colors.blue, Colors.teal, Colors.orange, Colors.purple, Colors.redAccent];
                                return PieChartSectionData(
                                  color: colors[i % colors.length],
                                  value: val,
                                  title: '\${(val / data.totalExpenses * 100).toStringAsFixed(0)}%',
                                  radius: 60,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }).toList(),
                            ),
                          ),
                    ),
                  ),
                ),
                // Vendor Legend
                if (data.spendData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: data.spendData.asMap().entries.map((e) {
                        final colors = [Colors.blue, Colors.teal, Colors.orange, Colors.purple, Colors.redAccent];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: colors[e.key % colors.length]),
                            const SizedBox(width: 4),
                            Text(e.value['name'], style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 24),

                // Cash Flow Forecast
                Text(l10n.cashFlowForecast, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _CashFlowRow(label: 'Overdue', amount: data.cashFlowOverdue, color: Colors.red),
                        const Divider(),
                        _CashFlowRow(label: 'Next 30 Days', amount: data.cashFlowNext30, color: Colors.orange),
                        const Divider(),
                        _CashFlowRow(label: '31-60 Days', amount: data.cashFlowNext60, color: Colors.blue),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.expectedIn, style: const TextStyle(color: Colors.grey)),
                                Text('+${data.cashFlowReceivables.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(l10n.expectedOut, style: const TextStyle(color: Colors.grey)),
                                Text('-${data.cashFlowPayables.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;

  const _KPICard({required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              amount >= 1000000 ? '\${(amount / 1000000).toStringAsFixed(1)}M' :
              amount >= 1000 ? '\${(amount / 1000).toStringAsFixed(1)}k' : 
              amount.toStringAsFixed(0),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _CashFlowRow({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          Text('\${amount.toStringAsFixed(0)} DA', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
