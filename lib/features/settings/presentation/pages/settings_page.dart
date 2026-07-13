import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notifNewInvoice = true;
  bool _notifInvoiceApproved = true;
  bool _notifWeeklyDigest = false;

  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Old Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (oldPasswordController.text.isEmpty || newPasswordController.text.isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                    final email = Supabase.instance.client.auth.currentUser?.email;
                    if (email != null) {
                      await Supabase.instance.client.auth.signInWithPassword(email: email, password: oldPasswordController.text);
                    }
                    await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPasswordController.text));
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      setDialogState(() => isLoading = false);
                    }
                  }
                },
                child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update'),
              ),
            ],
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t?.settings ?? 'Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: t?.profileDetails ?? 'Profile Details'),
          ListTile(
            title: Text(t?.fullName ?? 'Full Name'),
            subtitle: Text(userState.value?.fullName ?? 'User'),
            leading: const Icon(Icons.person_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: Text(t?.emailAddress ?? 'Email Address'),
            subtitle: Text(userState.value?.email ?? 'example@domain.com'),
            leading: const Icon(Icons.email_outlined),
          ),
          
          const Divider(),
          _SectionHeader(title: t?.securityRole ?? 'Security & Role'),
          ListTile(
            title: Text(t?.currentRole ?? 'Current Role'),
            subtitle: Text((userState.value?.role ?? 'staff').toUpperCase()),
            leading: const Icon(Icons.admin_panel_settings_outlined),
          ),
          ListTile(
            title: Text(t?.twoFactorAuth ?? 'Two-Factor Authentication'),
            subtitle: Text(t?.notConfigured ?? 'Not configured'),
            leading: const Icon(Icons.security_outlined),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please use the Web App to configure 2FA.')));
            },
          ),
          ListTile(
            title: const Text('Change Password'),
            leading: const Icon(Icons.password_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
          ),
          
          const Divider(),
          _SectionHeader(title: t?.notifications ?? 'Notifications'),
          SwitchListTile(
            title: Text(t?.newInvoiceCreated ?? 'New invoice created'),
            value: _notifNewInvoice,
            onChanged: (val) => setState(() => _notifNewInvoice = val),
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          SwitchListTile(
            title: Text(t?.invoiceApproved ?? 'Invoice approved'),
            value: _notifInvoiceApproved,
            onChanged: (val) => setState(() => _notifInvoiceApproved = val),
            secondary: const Icon(Icons.check_circle_outline),
          ),
          SwitchListTile(
            title: Text(t?.weeklyDigest ?? 'Weekly digest'),
            value: _notifWeeklyDigest,
            onChanged: (val) => setState(() => _notifWeeklyDigest = val),
            secondary: const Icon(Icons.mail_outline),
          ),
          
          const Divider(),
          _SectionHeader(title: t?.appearance ?? 'Appearance'),
          SwitchListTile(
            title: Text(t?.darkMode ?? 'Dark Mode'),
            subtitle: Text(t?.toggleTheme ?? 'Toggle the application theme'),
            value: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).setDarkMode(val);
            },
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(),
          _SectionHeader(title: t?.algerianSettings ?? 'Localization & Algerian Settings'),
          if (userState.value?.role == 'owner') ...[
            ListTile(
              title: Text(t?.taxFiscalRules ?? 'Tax & Fiscal Rules'),
              subtitle: Text(t?.taxFiscalRulesDesc ?? 'Timbre Fiscal, TVA rates'),
              leading: const Icon(Icons.calculate_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to TaxSettingsPage
              },
            ),
            ListTile(
              title: Text(t?.exchangeRates ?? 'Exchange Rates'),
              subtitle: Text(t?.exchangeRatesDesc ?? 'Official & Parallel rates'),
              leading: const Icon(Icons.currency_exchange),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to ExchangeRatesPage
              },
            ),
            ListTile(
              title: Text(t?.companyDocsStamp ?? 'Company Documents & Stamp'),
              subtitle: Text(t?.companyDocsStampDesc ?? 'Upload Cachet & Signature'),
              leading: const Icon(Icons.domain_verification),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to CompanyDocsPage
              },
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: Text(
              'SyncLedger v1.0.0\n© 2026 Equinox',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
