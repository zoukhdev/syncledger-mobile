import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../domain/models/contract_model.dart';
import 'contract_phases_page.dart';
import '../../providers/contracts_provider.dart';

class ContractDetailsPage extends ConsumerStatefulWidget {
  final ContractModel contract;

  const ContractDetailsPage({super.key, required this.contract});

  @override
  ConsumerState<ContractDetailsPage> createState() => _ContractDetailsPageState();
}

class _ContractDetailsPageState extends ConsumerState<ContractDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);
      try {
        final file = File(result.files.single.path!);
        final ext = result.files.single.extension;
        final fileName = '${widget.contract.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await Supabase.instance.client.storage
            .from('documents')
            .upload('contracts/$fileName', file);

        final docUrl = Supabase.instance.client.storage
            .from('documents')
            .getPublicUrl('contracts/$fileName');

        await Supabase.instance.client
            .from('contracts')
            .update({'document_url': docUrl})
            .eq('id', widget.contract.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully')));
          ref.refresh(contractsProvider);
          Navigator.pop(context); // Go back to refresh list, or ideally just update local state
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _viewDocument(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // We get the latest contract data from the provider
    final contractsState = ref.watch(contractsProvider);
    ContractModel currentContract = widget.contract;
    
    if (contractsState.value != null) {
      final updated = contractsState.value!.where((c) => c.id == widget.contract.id).toList();
      if (updated.isNotEmpty) {
        currentContract = updated.first;
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(currentContract.contractTitle, style: TextStyle(color: cs.onSurface)),
        iconTheme: IconThemeData(color: cs.onSurface),
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Phases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Details Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(cs, currentContract),
                const SizedBox(height: 24),
                Text('Contract Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: currentContract.documentUrl == null
                      ? Column(
                          children: [
                            Icon(Icons.description_outlined, size: 48, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No document attached to this contract.', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _uploadDocument,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: _isUploading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                    : const Icon(Icons.upload_file),
                                label: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(Icons.check_circle, size: 48, color: Colors.green.shade600),
                            const SizedBox(height: 16),
                            Text('Document is available.', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _viewDocument(currentContract.documentUrl),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: cs.primary),
                                ),
                                icon: Icon(Icons.visibility, color: cs.primary),
                                label: Text('View Full Document', style: TextStyle(color: cs.primary)),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          
          // Phases Tab (reusing existing page but without Scaffold)
          ContractPhasesView(contract: currentContract),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme cs, ContractModel contract) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDetailRow(cs, 'Title', contract.contractTitle),
          const Divider(height: 32),
          _buildDetailRow(cs, 'Contractor', contract.contractorName ?? 'N/A'),
          const Divider(height: 32),
          _buildDetailRow(cs, 'Total Amount', '${contract.totalAmount.toStringAsFixed(2)} DZD'),
          const Divider(height: 32),
          _buildDetailRow(cs, 'Status', (contract.status ?? 'Active').toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(ColorScheme cs, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// Extracted inner view from contract_phases_page.dart
class ContractPhasesView extends ConsumerWidget {
  final ContractModel contract;
  
  const ContractPhasesView({super.key, required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phasesAsync = ref.watch(contractPhasesProvider(contract.id));
    final cs = Theme.of(context).colorScheme;

    return phasesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (phases) {
        if (phases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No payment phases defined.', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: phases.length,
          itemBuilder: (context, index) {
            final phase = phases[index];
            return Card(
              color: cs.surfaceContainerLowest,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text('${index + 1}', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phase['phase_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
                          const SizedBox(height: 4),
                          Text('${phase['amount']} DZD', style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: phase['status'] == 'completed' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (phase['status'] as String).toUpperCase(),
                        style: TextStyle(
                          color: phase['status'] == 'completed' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
