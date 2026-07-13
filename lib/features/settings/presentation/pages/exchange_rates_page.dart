import 'package:flutter/material.dart';

class ExchangeRatesPage extends StatelessWidget {
  const ExchangeRatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exchange Rates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('EUR to DZD (Official)'),
            subtitle: Text('145.50'),
            trailing: Icon(Icons.edit),
          ),
          Divider(),
          ListTile(
            title: Text('EUR to DZD (Parallel)'),
            subtitle: Text('235.00'),
            trailing: Icon(Icons.edit),
          ),
        ],
      ),
    );
  }
}
