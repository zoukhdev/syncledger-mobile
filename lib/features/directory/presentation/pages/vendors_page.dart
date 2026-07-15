import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/directory_list_view.dart';
import '../widgets/new_contractor_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/localization/locale_provider.dart';

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
        title: const Text(
          'Equinox',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final currentLocale = ref.watch(localeProvider).languageCode;
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentLocale,
                  icon: const Icon(Icons.language, color: Color(0xFF1E293B)),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fr', child: Text('FR')),
                    DropdownMenuItem(value: 'en', child: Text('EN')),
                    DropdownMenuItem(value: 'ar', child: Text('AR')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(localeProvider.notifier).setLocale(val);
                    }
                  },
                ),
              );
            }
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Consumer(
              builder: (context, ref, child) {
                final userState = ref.watch(authProvider);
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Light blue-grey background
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    userState.value?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Color(0xFF3366CC),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF3366CC),
          shape: const CircleBorder(),
          elevation: 4,
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
      ),
      body: const DirectoryListView(table: 'vendors', title: 'Vendors'),
    );
  }
}
