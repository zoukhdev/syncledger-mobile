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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(l10n.analytics),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.blue),
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
                // Date Range Picker Placeholder
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      const Text('Oct 1 - Dec 31, 2023', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // KPI Cards
                Row(
                  children: [
                    Expanded(
                      child: _KPICard(
                        title: 'Net Profit', 
                        amount: '${data.netProfit >= 0 ? '' : '-'}${data.netProfit.abs().toStringAsFixed(0)} DZD', 
                        trend: '+12%', 
                        isPositive: data.netProfit >= 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KPICard(
                        title: 'Burn Rate', 
                        amount: '${data.totalExpenses.toStringAsFixed(0)} DZD', 
                        trend: '-5%', 
                        isPositive: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Expense Categories (Donut Chart)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expense Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: data.spendData.isEmpty 
                          ? Center(child: Text(l10n.noExpenseData))
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 60,
                                    sections: data.spendData.asMap().entries.map((e) {
                                      final i = e.key;
                                      final val = e.value['value'] as double;
                                      final colors = [
                                        const Color(0xFF1E88E5), // Marketing
                                        const Color(0xFFFFA000), // Operations
                                        const Color(0xFF9C27B0), // Development
                                        const Color(0xFF4CAF50), // Salaries
                                        Colors.grey,
                                      ];
                                      return PieChartSectionData(
                                        color: colors[i % colors.length],
                                        value: val,
                                        title: '${(val / data.totalExpenses * 100).toStringAsFixed(0)}%',
                                        radius: 40,
                                        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Total', style: TextStyle(color: Colors.black54, fontSize: 14)),
                                    Text(
                                      '${data.totalExpenses >= 1000 ? (data.totalExpenses/1000).toStringAsFixed(1) + 'k' : data.totalExpenses.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 24),
                      // Vendor Legend
                      if (data.spendData.isNotEmpty)
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: data.spendData.asMap().entries.map((e) {
                            final colors = [
                              const Color(0xFF1E88E5), 
                              const Color(0xFFFFA000), 
                              const Color(0xFF9C27B0), 
                              const Color(0xFF4CAF50), 
                              Colors.grey,
                            ];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10, 
                                  height: 10, 
                                  decoration: BoxDecoration(
                                    color: colors[e.key % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${e.value['name']}: ', 
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                Text(
                                  '${e.value['value'].toStringAsFixed(0)}', 
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),

                // Monthly Comparison (Bar chart)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 250,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: [data.totalRevenue, data.totalExpenses, 1000.0].reduce((a, b) => a > b ? a : b) * 1.2,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    if (value < 0 || value >= data.pnlData.length) return const Text('');
                                    return Text(data.pnlData[value.toInt()]['month'], style: const TextStyle(color: Colors.black54, fontSize: 12));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const Text('0', style: TextStyle(color: Colors.black54, fontSize: 12));
                                    return Text('${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: Colors.black54, fontSize: 12));
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: ([data.totalRevenue, data.totalExpenses, 1000.0].reduce((a, b) => a > b ? a : b) * 1.2) / 4,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: data.pnlData.asMap().entries.map((e) {
                              final i = e.key;
                              final rev = e.value['revenue'] as double;
                              final exp = e.value['expenses'] as double;
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: rev, 
                                    color: const Color(0xFF007AFF), // Primary Blue
                                    width: 24,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                  BarChartRodData(
                                    toY: exp, 
                                    color: const Color(0xFFFFA000), // Orange
                                    width: 24,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  final String amount;
  final String trend;
  final bool isPositive;

  const _KPICard({
    required this.title, 
    required this.amount, 
    required this.trend, 
    required this.isPositive
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down, 
                color: isPositive ? Colors.green : Colors.red, 
                size: 20
              ),
              const SizedBox(width: 4),
              Text(
                trend, 
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red, 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount, 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          const Text("vs Previous Quarter", style: TextStyle(color: Colors.black38, fontSize: 12)),
        ],
      ),
    );
  }
}
