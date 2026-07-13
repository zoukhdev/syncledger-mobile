import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ),
          
          const Divider(),
          _SectionHeader(title: t?.notifications ?? 'Notifications'),
          SwitchListTile(
            title: Text(t?.newInvoiceCreated ?? 'New invoice created'),
            value: true,
            onChanged: (val) {},
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          SwitchListTile(
            title: Text(t?.invoiceApproved ?? 'Invoice approved'),
            value: true,
            onChanged: (val) {},
            secondary: const Icon(Icons.check_circle_outline),
          ),
          SwitchListTile(
            title: Text(t?.weeklyDigest ?? 'Weekly digest'),
            value: false,
            onChanged: (val) {},
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
