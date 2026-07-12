import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Profile Details'),
          ListTile(
            title: const Text('Full Name'),
            subtitle: Text(userState.value?.fullName ?? 'User'),
            leading: const Icon(Icons.person_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Email Address'),
            subtitle: Text(userState.value?.email ?? 'example@domain.com'),
            leading: const Icon(Icons.email_outlined),
          ),
          
          const Divider(),
          const _SectionHeader(title: 'Security & Role'),
          ListTile(
            title: const Text('Current Role'),
            subtitle: Text((userState.value?.role ?? 'staff').toUpperCase()),
            leading: const Icon(Icons.admin_panel_settings_outlined),
          ),
          const ListTile(
            title: Text('Two-Factor Authentication'),
            subtitle: Text('Not configured'),
            leading: Icon(Icons.security_outlined),
          ),
          
          const Divider(),
          const _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            title: const Text('New invoice created'),
            value: true,
            onChanged: (val) {},
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          SwitchListTile(
            title: const Text('Invoice approved'),
            value: true,
            onChanged: (val) {},
            secondary: const Icon(Icons.check_circle_outline),
          ),
          SwitchListTile(
            title: const Text('Weekly digest'),
            value: false,
            onChanged: (val) {},
            secondary: const Icon(Icons.mail_outline),
          ),
          
          const Divider(),
          const _SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle the application theme'),
            value: themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark),
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).setDarkMode(val);
            },
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(),
          const _SectionHeader(title: 'Localization & Algerian Settings'),
          ListTile(
            title: const Text('Tax & Fiscal Rules'),
            subtitle: const Text('Timbre Fiscal, TVA rates'),
            leading: const Icon(Icons.calculate_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to TaxSettingsPage
            },
          ),
          ListTile(
            title: const Text('Exchange Rates'),
            subtitle: const Text('Official & Parallel rates'),
            leading: const Icon(Icons.currency_exchange),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to ExchangeRatesPage
            },
          ),
          ListTile(
            title: const Text('Company Documents & Stamp'),
            subtitle: const Text('Upload Cachet & Signature'),
            leading: const Icon(Icons.domain_verification),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to CompanyDocsPage
            },
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
