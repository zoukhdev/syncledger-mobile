import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../presentation/providers/analytics_provider.dart';

class PdfReportGenerator {
  static Future<void> generateAndShareMonthlyReport(AnalyticsData data) async {
    final pdf = pw.Document();
    final formatCurrency = NumberFormat.currency(locale: 'en_DZ', symbol: 'DA');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generated: \${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Text('Summary (Last 6 Months)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Revenue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.totalRevenue))),
                ]),
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.totalExpenses))),
                ]),
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Net Profit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.netProfit), style: pw.TextStyle(color: data.netProfit >= 0 ? PdfColors.green700 : PdfColors.red700))),
                ]),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Text('Top 5 Vendors by Spend', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Vendor', 'Amount'],
              data: data.spendData.map((e) => [e['name'].toString(), formatCurrency.format(e['value'])]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),

            pw.SizedBox(height: 30),
            pw.Text('All Invoices', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    // Add invoices in separate pages if too long, MultiPage handles pagination
    final invoicesList = List.from(data.rawInvoices);
    invoicesList.sort((a, b) => (b['invoice_date'] ?? '').compareTo(a['invoice_date'] ?? ''));
    
    final chunkedInvoices = [];
    int chunkSize = 25;
    for (var i = 0; i < invoicesList.length; i += chunkSize) {
      chunkedInvoices.add(invoicesList.sublist(i, i + chunkSize > invoicesList.length ? invoicesList.length : i + chunkSize));
    }

    if (chunkedInvoices.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Table.fromTextArray(
                headers: ['Date', 'Type', 'Party', 'Status', 'Amount'],
                data: invoicesList.map((inv) => [
                  inv['invoice_date'] ?? '-',
                  inv['invoice_type'] == 'receivable' ? 'Revenue' : 'Expense',
                  (inv['contractors'] != null ? inv['contractors']['name'] : 'Unknown'),
                  inv['status']?.toString().replaceAll('_', ' ') ?? '-',
                  formatCurrency.format(double.tryParse(inv['amount'].toString()) ?? 0),
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.all(4),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              )
            ];
          }
        )
      );
    }

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Financial_Report.pdf');
  }
}
