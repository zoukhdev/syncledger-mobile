import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberEmail = false;
  bool _isLoading = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // We have a valid session, force biometric unlock to proceed
      await _attemptBiometricLogin(isAutoLogin: true);
    } else {
      _loadSavedEmail();
    }
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberEmail = true;
      });
    }
  }

  Future<void> _attemptBiometricLogin({bool isAutoLogin = false}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      const secureStorage = FlutterSecureStorage();
      final bioEmail = await secureStorage.read(key: 'bio_email');
      final bioPassword = await secureStorage.read(key: 'bio_password');

      if (session == null && (bioEmail == null || bioPassword == null)) {
         if (!isAutoLogin && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No biometrics setup. Please login with email first.')));
         }
         return;
      }

      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to unlock SyncLedger',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        
        if (didAuthenticate) {
           if (session == null && bioEmail != null && bioPassword != null) {
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.auth.signInWithPassword(email: bioEmail, password: bioPassword);
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
           }
           
           if (mounted) {
             context.go('/overview');
           }
        } else {
           if (isAutoLogin && mounted) {
             // Failed biometric on auto-login, force sign out for security
             await Supabase.instance.client.auth.signOut();
           }
        }
      } else {
        if (isAutoLogin && mounted) {
          context.go('/overview');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics not supported on this device.')));
        }
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
      if (mounted) {
        await Supabase.instance.client.auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed. Please log in again.'))
        );
      }
    }
  }

  Future<void> _promptBiometricSetup(String email, String password) async {
    const secureStorage = FlutterSecureStorage();
    final isSetup = await secureStorage.read(key: 'bio_email') != null;
    if (isSetup) {
      await secureStorage.write(key: 'bio_email', value: email);
      await secureStorage.write(key: 'bio_password', value: password);
      return;
    }

    final canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    if (!canAuthenticateWithBiometrics) return;

    if (!mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Biometric Login'),
        content: const Text('Would you like to use biometrics to login faster next time?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      final didAuth = await auth.authenticate(
        localizedReason: 'Please authenticate to enable biometric login',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (didAuth) {
        await secureStorage.write(key: 'bio_email', value: email);
        await secureStorage.write(key: 'bio_password', value: password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric login enabled!')));
        }
      }
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberEmail) {
          await prefs.setString('saved_email', email);
        } else {
          await prefs.remove('saved_email');
        }

        final user = response.user;
        if (user != null) {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('force_password_reset')
              .eq('id', user.id)
              .maybeSingle();

          final forceReset = profileRes?['force_password_reset'] as bool? ?? false;

          if (mounted) {
            ref.read(authProvider.notifier).loadUser();
            if (forceReset) {
              context.go('/change-password');
            } else {
              // Ask for biometric setup
              await _promptBiometricSetup(email, password);
              if (mounted) context.go('/overview');
            }
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } catch (error) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Unexpected error occurred'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F4), // surface-container-low
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  const Text(
                    'SyncLedger',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.0,
                      color: Color(0xFF1B1C1D), // on-background
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Secure access to your institutional ledger.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF434653), // on-surface-variant
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Login Form Container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // surface-container-lowest
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Input
                        const Text(
                          'INSTITUTIONAL EMAIL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: Color(0xFF434653),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@institution.com',
                            hintStyle: const TextStyle(color: Color(0xFF737784)),
                            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF737784), size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: const Color(0xFFC3C6D5).withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF094CB2), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password Input
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PASSPHRASE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: Color(0xFF434653),
                              ),
                            ),
                            Text(
                              'Recover Access',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF094CB2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(color: Color(0xFF737784)),
                            prefixIcon: const Icon(Icons.key_outlined, color: Color(0xFF737784), size: 20),
                            suffixIcon: const Icon(Icons.visibility_outlined, color: Color(0xFF737784), size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: const Color(0xFFC3C6D5).withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF094CB2), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Remember device
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberEmail,
                                onChanged: (value) => setState(() => _rememberEmail = value ?? false),
                                activeColor: const Color(0xFF094CB2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(color: const Color(0xFFC3C6D5).withOpacity(0.8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Remember device',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF434653),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Primary Action
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF094CB2), Color(0xFF3366CC)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF094CB2).withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Authorize Access',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                    ],
                                  ),
                          ),
                        ),

                        if (!kIsWeb) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFFDBDADB))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('OR', style: TextStyle(fontSize: 12, color: Color(0xFF737784), fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFDBDADB))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _attemptBiometricLogin,
                              icon: const Icon(Icons.fingerprint, color: Color(0xFF094CB2), size: 20),
                              label: const Text(
                                'Authenticate with Biometrics',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF094CB2)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE9E8E9), // surface-container-high
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, color: Color(0xFF6D5E00), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'End-to-end encrypted session.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF434653)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
