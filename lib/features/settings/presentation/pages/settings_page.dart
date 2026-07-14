import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import 'tax_settings_page.dart';
import 'exchange_rates_page.dart';
import 'company_docs_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Change Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Old Password'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF094CB2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) return;
                        setDialogState(() => isLoading = true);
                        try {
                          final email = Supabase.instance.client.auth.currentUser?.email;
                          if (email != null) {
                            await Supabase.instance.client.auth.signInWithPassword(
                                email: email, password: oldPasswordController.text);
                          }
                          await Supabase.instance.client.auth
                              .updateUser(UserAttributes(password: newPasswordController.text));

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully')));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    // We will use standard English strings for this new design if l10n is missing the exact keys
    final fullName = userState.value?.fullName ?? 'System User';
    final email = userState.value?.email ?? 'Not provided';
    final role = (userState.value?.role ?? 'Staff').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF094CB2)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
            color: Color(0xFF1B1C1D),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        children: [
          _SectionTitle(title: 'Profile Details'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'Full Name',
                subtitle: fullName,
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.mail_outline,
                title: 'Email Address',
                subtitle: email,
                showBorder: false,
              ),
            ],
          ),

          const SizedBox(height: 32),
          _SectionTitle(title: 'Security & Role'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.badge_outlined,
                title: 'Current Role',
                subtitle: role,
              ),
              _SettingsRow(
                icon: Icons.security_outlined,
                title: 'Two-Factor Authentication',
                subtitle: 'Not configured',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please use the Web App to configure 2FA.')));
                },
              ),
              _SettingsRow(
                icon: Icons.password_outlined,
                title: 'Change Password',
                subtitle: 'Last updated 3 months ago',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                onTap: _showChangePasswordDialog,
              ),
              _SettingsRow(
                icon: Icons.devices_outlined,
                title: 'Active Sessions',
                subtitle: 'Manage devices logged into your account',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                showBorder: false,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 32),
          _SectionTitle(title: 'Appearance'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Toggle application theme',
                trailing: Switch(
                  value: isDark,
                  activeColor: const Color(0xFF094CB2),
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).setDarkMode(val);
                  },
                ),
                showBorder: false,
              ),
            ],
          ),

          if (userState.value?.role == 'owner') ...[
            const SizedBox(height: 32),
            _SectionTitle(title: 'Organization'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.calculate_outlined,
                  title: 'Tax & Fiscal Rules',
                  subtitle: 'Manage TVA and Fiscal Stamp',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                  onTap: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const TaxSettingsPage()));
                  },
                ),
                _SettingsRow(
                  icon: Icons.currency_exchange_outlined,
                  title: 'Exchange Rates',
                  subtitle: 'Official & Parallel rates',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                  onTap: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const ExchangeRatesPage()));
                  },
                ),
                _SettingsRow(
                  icon: Icons.domain_verification_outlined,
                  title: 'Company Documents',
                  subtitle: 'Upload Cachet & Signature',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF434653)),
                  showBorder: false,
                  onTap: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const CompanyDocsPage()));
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 48),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout, color: Color(0xFFBA1A1A)),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBA1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'SyncLedger v1.0.0\n© 2026 Equinox',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Public Sans',
                color: Color(0xFF737784),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Color(0xFF434653), // text-on-surface-variant
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3C6D5).withOpacity(0.3)), // outline-variant at 15% opacity? roughly
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showBorder;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: Color(0xFFF5F3F4))) // surface-container-low
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF434653)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1B1C1D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF434653), // text-on-surface-variant
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
