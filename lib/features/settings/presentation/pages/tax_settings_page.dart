import 'package:flutter/material.dart';

class TaxSettingsPage extends StatelessWidget {
  const TaxSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tax & Fiscal Rules')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('VAT (TVA) Rate'),
            subtitle: Text('19%'),
            trailing: Icon(Icons.edit),
          ),
          Divider(),
          ListTile(
            title: Text('Fiscal Stamp (Timbre Fiscal)'),
            subtitle: Text('1% (Max 2500 DZD)'),
            trailing: Icon(Icons.edit),
          ),
        ],
      ),
    );
  }
}
