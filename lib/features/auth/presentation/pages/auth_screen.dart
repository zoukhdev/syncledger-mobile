import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to unlock SyncLedger',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        
        if (didAuthenticate) {
           final session = Supabase.instance.client.auth.currentSession;
           if (session != null && mounted) {
             context.go('/overview');
           } else if (mounted && !isAutoLogin) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active session. Please login with email first.')));
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

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberEmail) {
          await prefs.setString('saved_email', _emailController.text.trim());
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
              context.go('/overview');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SyncLedger',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberEmail,
                        onChanged: (value) => setState(() => _rememberEmail = value ?? false),
                      ),
                      const Text('Remember Email'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  if (!kIsWeb)
                    TextButton.icon(
                       onPressed: _attemptBiometricLogin,
                       icon: const Icon(Icons.fingerprint),
                       label: const Text('Login with Biometrics'),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
