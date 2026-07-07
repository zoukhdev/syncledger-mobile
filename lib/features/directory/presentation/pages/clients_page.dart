import 'package:flutter/material.dart';
import '../widgets/directory_list_view.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients Directory')),
      body: const DirectoryListView(type: 'receivable'),
    );
  }
}
