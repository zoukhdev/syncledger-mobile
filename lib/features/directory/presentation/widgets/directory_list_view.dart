import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../invoices/domain/models/invoice_model.dart';
import 'directory_detail_sheet.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DirectoryEntity {
  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final List<InvoiceModel> invoices;

  DirectoryEntity({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    required this.invoices,
  });

  double get totalSpend => invoices.fold(0, (sum, inv) => sum + inv.amount);
  int get activeInvoices => invoices.where((i) => i.status == 'pending_approval' || i.status == 'pending_payment').length;
  
  String get initials {
    if (name.isEmpty) return '??';
    final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }
}

final directoryProvider = FutureProvider.family<List<DirectoryEntity>, String>((ref, table) async {
  final response = await Supabase.instance.client
      .from(table)
      .select('*, invoices(*)')
      .order('created_at', ascending: false);

  final rawData = response as List;
  
  final List<DirectoryEntity> entities = [];
  
  for (var entityData in rawData) {
    final rawInvoices = entityData['invoices'] as List? ?? [];
    final allInvoices = rawInvoices.map((e) => InvoiceModel.fromJson(e)).toList();
    
    // Contractors and Vendors both typically have payable invoices (for their services/materials)
    final typedInvoices = allInvoices.where((inv) => inv.invoiceType == 'payable').toList();
    
    entities.add(DirectoryEntity(
      id: entityData['id'],
      name: entityData['company_name'],
      contactName: entityData['contact_name'],
      email: entityData['email'],
      phone: entityData['phone'],
      invoices: typedInvoices,
    ));
  }
  
  // Sort by total spend descending
  entities.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));

  return entities;
});

class DirectoryListView extends ConsumerWidget {
  final String table; // 'contractors' or 'vendors'
  final String title;
  const DirectoryListView({super.key, required this.table, required this.title});

  void _showDetails(BuildContext context, DirectoryEntity entity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DirectoryDetailSheet(entity: entity),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(directoryProvider(table));
    final t = AppLocalizations.of(context);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(t?.errorPrefix(err.toString()) ?? 'Error: $err')),
      data: (entities) {
        if (entities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(t?.noVendors ?? 'No records found.', style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(t?.noVendorsDesc ?? "You haven't added any records yet.", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF1F2937), // Deep slate/grey
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entity = entities[index];
                  return ContractorCard(
                    name: entity.name,
                    initials: entity.initials,
                    activeContracts: entity.activeInvoices,
                    totalAmount: entity.totalSpend.toStringAsFixed(2),
                    onTap: () => _showDetails(context, entity),
                  );
                },
                childCount: entities.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ContractorCard extends StatelessWidget {
  final String name;
  final String initials;
  final int activeContracts;
  final String totalAmount;
  final VoidCallback? onTap;

  const ContractorCard({
    super.key,
    required this.name,
    required this.initials,
    required this.activeContracts,
    required this.totalAmount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Contractor Avatar/Logo
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Light background for avatar
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0052CC), // Brand Blue
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Contractor Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937), // Dark slate
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$activeContracts Active",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280), // Muted grey
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$totalAmount DZD",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0052CC),
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
