import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsData {
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final List<Map<String, dynamic>> pnlData; // { 'month': 'Jan', 'revenue': 100, 'expenses': 50 }
  final List<Map<String, dynamic>> spendData; // { 'name': 'Vendor A', 'value': 500 }
  final double cashFlowOverdue;
  final double cashFlowNext30;
  final double cashFlowNext60;
  final double cashFlowReceivables;
  final double cashFlowPayables;
  final List<dynamic> rawInvoices;

  AnalyticsData({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.pnlData,
    required this.spendData,
    required this.cashFlowOverdue,
    required this.cashFlowNext30,
    required this.cashFlowNext60,
    required this.cashFlowReceivables,
    required this.cashFlowPayables,
    required this.rawInvoices,
  });
}

final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('invoices')
      .select('id, amount, status, invoice_type, invoice_date, due_date, contractor_id, contractors(name)');
      
  final invoices = response as List<dynamic>;

  double totalRevenue = 0;
  double totalExpenses = 0;

  // 1. P&L Data (Last 6 months)
  Map<String, Map<String, dynamic>> monthsMap = {};
  for (int i = 5; i >= 0; i--) {
    final d = DateTime.now().subtract(Duration(days: 30 * i));
    final monthKey = "\${d.year}-\${d.month.toString().padLeft(2, '0')}";
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    monthsMap[monthKey] = {
      'month': monthNames[d.month - 1],
      'revenue': 0.0,
      'expenses': 0.0,
      'sortKey': d.year * 100 + d.month,
    };
  }

  // 2. Vendor Spend
  Map<String, double> contractorSpend = {};

  // 3. Cash Flow
  double overdue = 0;
  double next30 = 0;
  double next60 = 0;
  double receivables = 0;
  double payables = 0;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  for (var inv in invoices) {
    final amount = double.tryParse(inv['amount'].toString()) ?? 0.0;
    
    // P&L and Spend
    if (inv['invoice_date'] != null) {
      final date = DateTime.parse(inv['invoice_date']);
      final monthKey = "\${date.year}-\${date.month.toString().padLeft(2, '0')}";
      
      if (monthsMap.containsKey(monthKey)) {
        if (inv['invoice_type'] == 'receivable') {
          monthsMap[monthKey]!['revenue'] += amount;
          totalRevenue += amount;
        } else {
          monthsMap[monthKey]!['expenses'] += amount;
          totalExpenses += amount;
        }
      }
      
      if (inv['invoice_type'] == 'payable') {
        final name = (inv['contractors'] != null && inv['contractors']['name'] != null) 
            ? inv['contractors']['name'] 
            : 'Unknown';
        contractorSpend[name] = (contractorSpend[name] ?? 0) + amount;
      }
    }

    // Cash flow
    if (inv['status'] != 'paid' && inv['due_date'] != null) {
      final dueDate = DateTime.parse(inv['due_date']);
      final dueDateDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final diffDays = dueDateDate.difference(todayDate).inDays;

      if (inv['invoice_type'] == 'receivable') receivables += amount;
      else payables += amount;

      if (diffDays < 0) overdue += amount;
      else if (diffDays <= 30) next30 += amount;
      else if (diffDays <= 60) next60 += amount;
    }
  }

  final pnlData = monthsMap.values.toList();
  pnlData.sort((a, b) => (a['sortKey'] as int).compareTo(b['sortKey'] as int));

  final spendList = contractorSpend.entries.map((e) => {
    'name': e.key,
    'value': e.value,
  }).toList();
  spendList.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
  final topSpend = spendList.take(5).toList();

  return AnalyticsData(
    totalRevenue: totalRevenue,
    totalExpenses: totalExpenses,
    netProfit: totalRevenue - totalExpenses,
    pnlData: pnlData,
    spendData: topSpend,
    cashFlowOverdue: overdue,
    cashFlowNext30: next30,
    cashFlowNext60: next60,
    cashFlowReceivables: receivables,
    cashFlowPayables: payables,
    rawInvoices: invoices,
  );
});
