import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen for verifying a TOTP code when MFA is required after login.
class MfaVerifyPage extends StatefulWidget {
  const MfaVerifyPage({super.key});
  @override
  State<MfaVerifyPage> createState() => _MfaVerifyPageState();
}

class _MfaVerifyPageState extends State<MfaVerifyPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final totpFactor = factors.totp.isNotEmpty ? factors.totp.first : null;
      if (totpFactor == null) {
        setState(() { _error = 'No MFA factor found.'; _isLoading = false; });
        return;
      }

      final challenge = await Supabase.instance.client.auth.mfa.challenge(factorId: totpFactor.id);
      await Supabase.instance.client.auth.mfa.verify(
        factorId: totpFactor.id,
        challengeId: challenge.id,
        code: code,
      );

      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Verification failed. Please try again.'; _isLoading = false; });
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
        title: Text('Two-Factor Verification', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security_rounded, size: 40, color: cs.primary),
              ),
              const SizedBox(height: 32),
              Text('Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 12),
              Text('Open your authenticator app and enter the 6-digit code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.5)),
              const SizedBox(height: 40),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 12, color: cs.onSurface),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(fontSize: 32, color: cs.onSurfaceVariant.withOpacity(0.4), letterSpacing: 12),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.primary, width: 2)),
                  errorText: _error,
                ),
                onChanged: (v) { if (v.length == 6) _verify(); },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
