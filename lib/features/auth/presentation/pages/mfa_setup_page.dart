import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen for enrolling in TOTP 2FA — shows QR code and confirms with a code.
class MfaSetupPage extends StatefulWidget {
  const MfaSetupPage({super.key});
  @override
  State<MfaSetupPage> createState() => _MfaSetupPageState();
}

class _MfaSetupPageState extends State<MfaSetupPage> {
  final _codeController = TextEditingController();
  bool _isEnrolling = true;
  bool _isVerifying = false;
  String? _error;
  String? _qrUri;
  String? _factorId;
  String? _challengeId;

  @override
  void initState() {
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() => _isEnrolling = true);
    try {
      final res = await Supabase.instance.client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'SyncLedger',
      );
      final challenge = await Supabase.instance.client.auth.mfa.challenge(factorId: res.id);
      if (mounted) {
        setState(() {
          _qrUri = res.totp?.qrCode;
          _factorId = res.id;
          _challengeId = challenge.id;
          _isEnrolling = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isEnrolling = false; });
    }
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code from your authenticator app.');
      return;
    }
    if (_factorId == null || _challengeId == null) return;
    setState(() { _isVerifying = true; _error = null; });
    try {
      await Supabase.instance.client.auth.mfa.verify(
        factorId: _factorId!,
        challengeId: _challengeId!,
        code: code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Two-Factor Authentication enabled!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; _isVerifying = false; });
    } catch (e) {
      setState(() { _error = 'Verification failed. Please try again.'; _isVerifying = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Setup Two-Factor Auth', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isEnrolling
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _qrUri == null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, size: 56, color: cs.error),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 24),
                      ElevatedButton(onPressed: _enroll, child: const Text('Retry')),
                    ]),
                  ))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Step 1
                        _Step(number: '1', title: 'Install an Authenticator App',
                            description: 'Download Google Authenticator, Authy, or any TOTP app on your phone.', cs: cs),
                        const SizedBox(height: 24),

                        // Step 2 - QR Code
                        _Step(number: '2', title: 'Scan the QR Code', description: 'Open your authenticator app and scan this code.', cs: cs),
                        const SizedBox(height: 16),
                        if (_qrUri != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.outline.withOpacity(0.3)),
                              ),
                              child: QrImageView(data: _qrUri!, size: 200),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Step 3 - Enter Code
                        _Step(number: '3', title: 'Enter Verification Code',
                            description: 'Enter the 6-digit code shown in your authenticator app to confirm setup.', cs: cs),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 10, color: cs.onSurface),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: TextStyle(fontSize: 28, color: cs.onSurfaceVariant.withOpacity(0.4), letterSpacing: 10),
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.primary, width: 2)),
                            errorText: _error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isVerifying ? null : _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isVerifying
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                              : const Text('Enable 2FA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final ColorScheme cs;
  const _Step({required this.number, required this.title, required this.description, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Center(child: Text(number, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 14))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.4)),
          ]),
        ),
      ],
    );
  }
}
