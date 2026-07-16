import 'dart:io';

void main() async {
  final filesToFix = [
    r"lib/features/overview/presentation/pages/overview_page.dart",
    r"lib/features/staff/presentation/pages/staff_page.dart",
    r"lib/features/purchase_orders/presentation/pages/purchase_orders_page.dart",
    r"lib/features/purchase_orders/presentation/pages/purchase_order_detail_page.dart",
    r"lib/features/invoices/presentation/pages/invoices_page.dart",
    r"lib/features/settings/presentation/pages/settings_page.dart",
    r"lib/features/settings/presentation/pages/tax_settings_page.dart",
    r"lib/features/scanner/presentation/pages/ocr_scan_page.dart",
    r"lib/features/onboarding/presentation/pages/onboarding_page.dart",
    r"lib/features/registers/presentation/pages/registers_page.dart",
    r"lib/features/caisse/presentation/pages/caisse_page.dart"
  ];

  final replacements = {
    "backgroundColor: Colors.white": "backgroundColor: Theme.of(context).colorScheme.surface",
    "color: const Color(0xFFF3F4F6)": "color: Theme.of(context).colorScheme.surfaceContainer",
    "color: Color(0xFFF3F4F6)": "color: Theme.of(context).colorScheme.surfaceContainer",
    "color: const Color(0xFF111827)": "color: Theme.of(context).colorScheme.onSurface",
    "color: Color(0xFF111827)": "color: Theme.of(context).colorScheme.onSurface",
    "color: Colors.black.withOpacity(0.04)": "color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04)",
    "color: Colors.black87": "color: Theme.of(context).colorScheme.onSurface",
    "color: Colors.black54": "color: Theme.of(context).colorScheme.onSurfaceVariant",
    "color: Colors.black": "color: Theme.of(context).colorScheme.onSurface",
    "backgroundColor: Colors.black": "backgroundColor: Theme.of(context).colorScheme.surface",
  };

  for (final path in filesToFix) {
    final file = File(path);
    if (!await file.exists()) continue;

    String content = await file.readAsString();
    String original = content;

    for (final entry in replacements.entries) {
      content = content.replaceAll(entry.key, entry.value);
    }

    if (content != original) {
      await file.writeAsString(content);
      print('Updated $path');
    }
  }
}
