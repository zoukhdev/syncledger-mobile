import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../presentation/providers/analytics_provider.dart';

class PdfReportGenerator {
  static Future<void> generateAndShareMonthlyReport(AnalyticsData data, AppLocalizations l10n) async {
    final formatCurrency = NumberFormat.currency(locale: 'en_DZ', symbol: 'DA');
    
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(l10n.financialReport, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${l10n.generated} ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              )
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Text(l10n.summaryLast6Months, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l10n.totalRevenue, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.totalRevenue))),
                  ]
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l10n.totalExpenses, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.totalExpenses))),
                  ]
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l10n.netProfit, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(data.netProfit))),
                  ]
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            pw.Text(l10n.topVendors, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [l10n.vendor, l10n.amount],
              data: data.spendData.map((e) => [e['name'].toString(), formatCurrency.format(e['value'])]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellHeight: 30,
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
            ),

            pw.SizedBox(height: 30),

            pw.Text(l10n.allInvoices, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    // Filter and sort invoices for the table
    final invoicesList = List<Map<String, dynamic>>.from(data.rawInvoices);
    invoicesList.sort((a, b) => (b['invoice_date'] ?? '').compareTo(a['invoice_date'] ?? ''));

    // If there are many invoices, add them as a separate table to handle page breaks naturally
    if (invoicesList.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: [l10n.date, l10n.type, l10n.party, l10n.status, l10n.amount],
                data: invoicesList.map((inv) => [
                  inv['invoice_date'] ?? '-',
                  inv['invoice_type'] == 'receivable' ? l10n.revenue : l10n.expense,
                  (inv['contractors'] != null ? inv['contractors']['name'] : l10n.unknown),
                  inv['status']?.toString().replaceAll('_', ' ') ?? '-',
                  formatCurrency.format(double.tryParse(inv['amount'].toString()) ?? 0),
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
            ];
          }
        )
      );
    }

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Financial_Report.pdf');
  }
}
