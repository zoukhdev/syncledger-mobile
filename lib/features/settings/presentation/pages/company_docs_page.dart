import 'package:flutter/material.dart';

class CompanyDocsPage extends StatelessWidget {
  const CompanyDocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA), // surface-container-lowest
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF094CB2)), // primary
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF1B1C1D),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF094CB2)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            // Context Header
            const Text(
              'Company Documents',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1C1D),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Manage and update essential corporate files and authorized signatures for your records.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Color(0xFF434653), // text-on-surface-variant
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Document Cards
            _DocumentCard(
              title: 'Company Cachet',
              status: 'Uploaded (cachet.png)',
              isUploaded: true,
              onUpload: () {},
            ),
            const SizedBox(height: 16),
            _DocumentCard(
              title: 'Authorized Signature',
              status: 'Uploaded (signature.png)',
              isUploaded: true,
              onUpload: () {},
            ),

            const SizedBox(height: 48),
            Center(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFEDEE), // surface-container
                  foregroundColor: const Color(0xFF094CB2), // primary
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'View History',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String status;
  final bool isUploaded;
  final VoidCallback onUpload;

  const _DocumentCard({
    required this.title,
    required this.status,
    required this.isUploaded,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onUpload,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3F4), // surface-container-low
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1C1D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isUploaded)
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDFE3E8), // secondary-container
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Color(0xFF606569)),
                        ),
                      Text(
                        status,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5A5F63), // secondary
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE3E2E3), // surface-container-highest
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_file, color: Color(0xFF094CB2)),
            ),
          ],
        ),
      ),
    );
  }
}
