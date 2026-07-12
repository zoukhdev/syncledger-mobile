import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/notifications/notification_service.dart';

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    _pageController = PageController(initialPage: widget.navigationShell.currentIndex);
  }

  @override
  void dispose() {
    NotificationService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != oldWidget.navigationShell.currentIndex) {
      _pageController.animateToPage(
        widget.navigationShell.currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onPageChanged(int index) {
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equinox', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      drawer: NavigationDrawer(
        selectedIndex: null, // we don't highlight the drawer items by default
        onDestinationSelected: (index) {
          Navigator.pop(context); // close drawer
          final isOwner = userState.value?.role == 'owner';
          if (index == 0) {
            context.push('/registers');
          } else if (index == 1) {
            context.push('/contracts');
          } else if (index == 2) {
            context.push('/caisse');
          } else if (isOwner && index == 3) {
            context.push('/audit');
          } else if (isOwner && index == 4) {
            context.push('/staff');
          } else if ((isOwner && index == 5) || (!isOwner && index == 3)) {
            context.push('/settings');
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    userState.value?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userState.value?.fullName ?? 'User',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  (userState.value?.role ?? 'staff').toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Divider(),
          ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.wallet_outlined),
              selectedIcon: const Icon(Icons.wallet),
              label: const Text('Cash Registers'),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.description_outlined),
              selectedIcon: const Icon(Icons.description),
              label: const Text('Contracts'),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.archive_outlined),
              selectedIcon: const Icon(Icons.archive),
              label: const Text('Caisse (Cash Box)'),
            ),
            if (userState.value?.role == 'owner') ...[
              NavigationDrawerDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: const Text('Audit Logs'),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.people_outlined),
                selectedIcon: const Icon(Icons.people),
                label: const Text('Staff'),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Divider(),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: const Text('Settings'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                ref.read(authProvider.notifier).signOut();
                context.go('/');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: widget.children,
      ),
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
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Invoices',
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
