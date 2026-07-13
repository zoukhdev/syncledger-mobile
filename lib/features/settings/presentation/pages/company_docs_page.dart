import 'package:flutter/material.dart';

class CompanyDocsPage extends StatelessWidget {
  const CompanyDocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Documents & Stamp')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('Company Cachet'),
            subtitle: Text('Uploaded (cachet.png)'),
            trailing: Icon(Icons.upload_file),
          ),
          Divider(),
          ListTile(
            title: Text('Authorized Signature'),
            subtitle: Text('Uploaded (signature.png)'),
            trailing: Icon(Icons.upload_file),
          ),
        ],
      ),
    );
  }
}
