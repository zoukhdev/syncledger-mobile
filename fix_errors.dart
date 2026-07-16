import 'dart:io';

void replaceInFile(String path, Map<String, String> replacements) {
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    return;
  }
  String content = file.readAsStringSync();
  bool changed = false;
  
  for (var entry in replacements.entries) {
    if (content.contains(entry.key)) {
      content = content.replaceAll(entry.key, entry.value);
      changed = true;
    }
  }
  
  if (changed) {
    file.writeAsStringSync(content);
    print('Updated $path');
  } else {
    print('No changes in $path');
  }
}

void replaceRegexInFile(String path, Map<RegExp, String> replacements) {
  final file = File(path);
  if (!file.existsSync()) {
    print('File not found: $path');
    return;
  }
  String content = file.readAsStringSync();
  bool changed = false;
  
  for (var entry in replacements.entries) {
    if (entry.key.hasMatch(content)) {
      content = content.replaceAll(entry.key, entry.value);
      changed = true;
    }
  }
  
  if (changed) {
    file.writeAsStringSync(content);
    print('Updated regex $path');
  }
}

void main() {
  // invoices_page.dart
  replaceInFile(
    'lib/features/invoices/presentation/pages/invoices_page.dart',
    {
      'style: const TextStyle(\n                    fontSize: 22,\n                    fontWeight: FontWeight.bold,\n                    letterSpacing: -0.5,\n                    color: Theme.of(context).colorScheme.onSurface,': 
      'style: TextStyle(\n                    fontSize: 22,\n                    fontWeight: FontWeight.bold,\n                    letterSpacing: -0.5,\n                    color: Theme.of(context).colorScheme.onSurface,',
    }
  );
  
  // overview_page.dart
  replaceInFile(
    'lib/features/overview/presentation/pages/overview_page.dart',
    {
      'const [BoxShadow(color: Theme.of(context).colorScheme.onSurface12': '[BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)',
      'const Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.onSurface)': 'Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.onSurface)',
      'const TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)': 'TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)',
      'const Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant)': 'Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant)',
    }
  );
  replaceRegexInFile(
    'lib/features/overview/presentation/pages/overview_page.dart',
    {
      RegExp(r'const TextStyle\(\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(color: Theme.of(context).colorScheme.onSurface,'
    }
  );
  
  // staff_page.dart
  replaceInFile(
    'lib/features/staff/presentation/pages/staff_page.dart',
    {
      'const BackButton(color: Theme.of(context).colorScheme.onSurface)': 'BackButton(color: Theme.of(context).colorScheme.onSurface)',
      'const Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface)': 'Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface)',
      'const Divider(height: 32, color: Theme.of(context).colorScheme.surfaceContainer, thickness: 1)': 'Divider(height: 32, color: Theme.of(context).colorScheme.surfaceContainer, thickness: 1)',
    }
  );
  replaceRegexInFile(
    'lib/features/staff/presentation/pages/staff_page.dart',
    {
      RegExp(r'const TextStyle\(\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,'
    }
  );

  // purchase_orders_page.dart
  replaceInFile(
    'lib/features/purchase_orders/presentation/pages/purchase_orders_page.dart',
    {
      'const BackButton(color: Theme.of(context).colorScheme.onSurface)': 'BackButton(color: Theme.of(context).colorScheme.onSurface)',
      'const Icon(Icons.tune, color: Theme.of(context).colorScheme.onSurface)': 'Icon(Icons.tune, color: Theme.of(context).colorScheme.onSurface)',
    }
  );
  replaceRegexInFile(
    'lib/features/purchase_orders/presentation/pages/purchase_orders_page.dart',
    {
      RegExp(r'const TextStyle\(\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,',
      RegExp(r'const TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,'
    }
  );

  // purchase_order_detail_page.dart
  replaceInFile(
    'lib/features/purchase_orders/presentation/pages/purchase_order_detail_page.dart',
    {
      'const BackButton(color: Theme.of(context).colorScheme.onSurface)': 'BackButton(color: Theme.of(context).colorScheme.onSurface)',
    }
  );
  replaceRegexInFile(
    'lib/features/purchase_orders/presentation/pages/purchase_order_detail_page.dart',
    {
      RegExp(r'const TextStyle\(\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,',
      RegExp(r'const TextStyle\(\s*fontSize:\s*20,\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface,',
      RegExp(r'const TextStyle\(\s*fontSize:\s*16,\s*fontWeight:\s*FontWeight\.bold,\s*color:\s*Theme\.of\(context\)\.colorScheme\.onSurface,'): 'TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface,'
    }
  );

  // contract_details_page.dart
  replaceInFile(
    'lib/features/contracts/presentation/pages/contract_details_page.dart',
    {
      'FilePicker.platform.pickFiles(': 'FilePicker.pickFiles(',
      'currentContract.title': 'currentContract.contractTitle',
      'contract.title': 'contract.contractTitle',
    }
  );
}
