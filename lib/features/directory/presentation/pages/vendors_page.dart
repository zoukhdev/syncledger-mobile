import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/directory_list_view.dart';
import '../widgets/new_contractor_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VendorsPage extends ConsumerWidget {
  const VendorsPage({super.key});

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    try {
      final entities = await ref.read(directoryProvider('vendors').future);
      
      final buffer = StringBuffer();
      buffer.writeln('Vendor Name,Total Invoices,Total Spend (DZD),Pending Invoices');
      
      for (var entity in entities) {
        // Escape quotes
        final name = entity.name.replaceAll('"', '""');
        buffer.writeln('"$name",${entity.invoices.length},${entity.totalSpend.toStringAsFixed(2)},${entity.activeInvoices}');
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/vendors_${DateTime.now().toIso8601String().split('T')[0]}.csv';
      final file = File(path);
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles([XFile(path)], text: 'Vendors Directory');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.search, color: Colors.black87),
          onPressed: () {
            // Placeholder for search action
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'export') {
                _exportCsv(context, ref);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'export',
                  child: Text(t?.exportDirectory ?? 'Export CSV'),
                ),
              ];
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Color(0xFFE5E7EB),
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'), // Placeholder avatar
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0052CC),
        shape: const CircleBorder(),
        tooltip: t?.addVendor ?? 'Add Vendor',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => NewContractorDialog(title: t?.addVendor ?? 'Add Vendor', table: 'vendors'),
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: const DirectoryListView(table: 'vendors', title: 'Vendors'),
    );
  }
}
