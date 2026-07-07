import 'package:flutter/material.dart';
import '../widgets/directory_list_view.dart';

class VendorsPage extends StatelessWidget {
  const VendorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors Directory')),
      body: const DirectoryListView(type: 'payable'),
    );
  }
}
