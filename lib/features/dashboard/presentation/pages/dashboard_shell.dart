import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/notifications/notification_service.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
  }

  @override
  void dispose() {
    NotificationService.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SyncLedger'),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.surface),
              accountName: Text(
                userState.value?.fullName ?? 'User',
                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                userState.value?.role ?? 'staff',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  userState.value?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wallet),
              title: const Text('Cash Registers'),
              onTap: () {
                Navigator.pop(context);
                context.push('/registers');
              },
            ),
            if (userState.value?.role == 'owner') ...[
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Audit Logs'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/audit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Staff'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/staff');
                },
              ),
            ],
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(authProvider.notifier).signOut();
                context.go('/');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Vendors',
          ),
        ],
      ),
    );
  }
}
