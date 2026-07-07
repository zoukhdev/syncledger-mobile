import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

class BiometricGate extends StatefulWidget {
  final Widget child;

  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final LocalAuthentication auth = LocalAuthentication();
  late final AppLifecycleListener _listener;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _listener = AppLifecycleListener(
        onPause: _lockApp,
        onResume: _attemptUnlock,
      );
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _listener.dispose();
    }
    super.dispose();
  }

  void _lockApp() {
    setState(() => _isLocked = true);
  }

  Future<void> _attemptUnlock() async {
    if (!_isLocked) return;

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to resume',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        
        if (didAuthenticate && mounted) {
          setState(() => _isLocked = false);
        }
      } else {
        // Fallback if no biometrics setup
        setState(() => _isLocked = false);
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
      // Require manual unlock or re-auth depending on strictness
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'App Locked',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _attemptUnlock,
                        child: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
