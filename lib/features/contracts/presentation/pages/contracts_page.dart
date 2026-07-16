import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/contracts_provider.dart';
import '../widgets/create_contract_dialog.dart';
import 'contract_phases_page.dart';
import 'contract_details_page.dart';

class ContractsPage extends ConsumerStatefulWidget {
  const ContractsPage({super.key});

  @override
  ConsumerState<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends ConsumerState<ContractsPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final contractsState = ref.watch(contractsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Contracts', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D1B3E))),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D1B3E)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: const CircleBorder(),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CreateContractDialog(),
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search contracts...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey), 
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                }
                              ) 
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052CC), // Professional blue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: () {
                      // Filter action (placeholder)
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: contractsState.when(
              data: (allContracts) {
                final contracts = allContracts.where((c) {
                  if (_searchQuery.isNotEmpty) {
                    if (!c.contractTitle.toLowerCase().contains(_searchQuery.toLowerCase()) && 
                        !(c.contractorName ?? '').toLowerCase().contains(_searchQuery.toLowerCase())) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (contracts.isEmpty) {
                  return const Center(child: Text('No active contracts found.', style: TextStyle(color: Colors.grey)));
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(contractsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: contracts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final contract = contracts[index];
                      // Note: We are mocking status for UI display based on logic if available, else 'In Progress'
                      return ContractCard(
                        title: contract.contractTitle,
                        clientName: contract.contractorName ?? 'Unknown Vendor',
                        amount: contract.totalAmount.toStringAsFixed(2),
                        status: 'In Progress', // Fallback status
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ContractDetailsPage(contract: contract)));
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class ContractCard extends StatelessWidget {
  final String title;
  final String clientName;
  final String amount;
  final String status;
  final VoidCallback? onTap;

  const ContractCard({
    super.key,
    required this.title,
    required this.clientName,
    required this.amount,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isInProgress = status.toLowerCase() == 'in progress';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D1B3E), // Deep Navy
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF0D1B3E)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "DZD $amount",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B3E),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isInProgress ? const Color(0xFF0D1B3E) : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
