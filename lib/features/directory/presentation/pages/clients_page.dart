import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/directory_list_view.dart';
import '../widgets/new_contractor_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    try {
      final entities = await ref.read(directoryProvider('contractors').future);
      
      final buffer = StringBuffer();
      buffer.writeln('Vendor Name,Total Invoices,Total Spend (DZD),Pending Invoices');
      
      for (var entity in entities) {
        // Escape quotes
        final name = entity.name.replaceAll('"', '""');
        buffer.writeln('"$name",${entity.invoices.length},${entity.totalSpend.toStringAsFixed(2)},${entity.activeInvoices}');
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/clients_${DateTime.now().toIso8601String().split('T')[0]}.csv';
      final file = File(path);
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles([XFile(path)], text: 'Clients Directory');
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
      appBar: AppBar(
        title: Text(t?.clients ?? 'Clients Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: t?.exportDirectory ?? 'Export Directory',
            onPressed: () => _exportCsv(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t?.addContractor ?? 'Add Contractor',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const NewContractorDialog(),
              );
            },
          ),
        ],
      ),
      body: const DirectoryListView(table: 'contractors'),
    );
  }
}
