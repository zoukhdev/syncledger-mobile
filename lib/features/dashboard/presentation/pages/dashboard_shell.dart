import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/localization/locale_provider.dart';

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
        title: const Text('Equinox', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: Consumer(
                builder: (context, ref, child) {
                  final currentLocale = ref.watch(localeProvider).languageCode;
                  return DropdownButton<String>(
                    value: currentLocale,
                    icon: const Icon(Icons.language, color: Colors.grey),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('FR')),
                      DropdownMenuItem(value: 'en', child: Text('EN')),
                      DropdownMenuItem(value: 'ar', child: Text('AR')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(localeProvider.notifier).setLocale(val);
                      }
                    },
                  );
                }
              ),
            ),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: null, // we don't highlight the drawer items by default
        onDestinationSelected: (index) {
          Navigator.pop(context); // close drawer
          final isOwner = userState.value?.role == 'owner';
          if (index == 0) {
            context.push('/analytics');
          } else if (index == 1) {
            context.push('/contracts');
          } else if (index == 2) {
            context.push('/purchase-orders');
          } else if (index == 3) {
            context.push('/registers');
          } else if (index == 4) {
            context.push('/caisse');
          } else if (isOwner && index == 5) {
            context.push('/staff');
          } else if (isOwner && index == 6) {
            context.push('/audit');
          } else if ((isOwner && index == 7) || (!isOwner && index == 5)) {
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1C1D), // on-background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    userState.value?.fullName.substring(0, 1).toUpperCase() ?? 'Z',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userState.value?.fullName ?? 'zoukh own',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1C1D),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (userState.value?.role ?? 'OWNER').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: Color(0xFF737784), // outline color
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Divider(),
          ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.bar_chart),
              selectedIcon: const Icon(Icons.bar_chart),
              label: Text(AppLocalizations.of(context)!.analyticsTab),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.description_outlined),
              selectedIcon: const Icon(Icons.description),
              label: Text(AppLocalizations.of(context)?.contracts ?? 'Contracts'),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.shopping_cart_outlined),
              selectedIcon: const Icon(Icons.shopping_cart),
              label: Text(AppLocalizations.of(context)?.purchaseOrders ?? 'Purchase Orders'),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.wallet_outlined),
              selectedIcon: const Icon(Icons.wallet),
              label: Text(AppLocalizations.of(context)?.cashRegisters ?? 'Cash Registers'),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.archive_outlined),
              selectedIcon: const Icon(Icons.archive),
              label: Text(AppLocalizations.of(context)?.caisse ?? 'Caisse'),
            ),
            if (userState.value?.role == 'owner') ...[
              NavigationDrawerDestination(
                icon: const Icon(Icons.people_outlined),
                selectedIcon: const Icon(Icons.people),
                label: Text(AppLocalizations.of(context)?.staff ?? 'Staff'),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: Text(AppLocalizations.of(context)?.auditLogs ?? 'Audit Logs'),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Divider(),
            ),
            NavigationDrawerDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: Text(AppLocalizations.of(context)?.settings ?? 'Settings'),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                ref.read(authProvider.notifier).signOut();
                context.go('/');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      body: IndexedStack(
        index: widget.navigationShell.currentIndex,
        children: widget.children,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(context, 0, Icons.dashboard_outlined, Icons.dashboard, AppLocalizations.of(context)?.overview ?? 'Overview'),
              _buildNavItem(context, 1, Icons.receipt_long_outlined, Icons.receipt_long, AppLocalizations.of(context)?.invoices ?? 'Invoices'),
              _buildNavItem(context, 2, Icons.group_outlined, Icons.group, AppLocalizations.of(context)?.clients ?? 'Contractors'),
              _buildNavItem(context, 3, Icons.storefront_outlined, Icons.storefront, AppLocalizations.of(context)?.vendors ?? 'Vendors'),
              _buildNavItem(context, 4, Icons.archive_outlined, Icons.archive, AppLocalizations.of(context)?.caisse ?? 'Caisse'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = widget.navigationShell.currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? iconFilled : iconOutlined,
            color: isSelected ? const Color(0xFF3366CC) : const Color(0xFF64748B),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.2,
              color: isSelected ? const Color(0xFF3366CC) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
