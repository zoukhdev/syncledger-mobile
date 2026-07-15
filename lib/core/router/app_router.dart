import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/pages/auth_screen.dart';
import '../../features/auth/presentation/pages/change_password_screen.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_shell.dart';
import '../../features/directory/presentation/pages/clients_page.dart';
import '../../features/directory/presentation/pages/vendors_page.dart';
import '../../features/overview/presentation/pages/overview_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import '../../features/audit/presentation/pages/audit_logs_page.dart';
import '../../features/registers/presentation/pages/registers_page.dart';
import '../../features/contracts/presentation/pages/contracts_page.dart';
import '../../features/caisse/presentation/pages/caisse_page.dart';
import '../../features/purchase_orders/presentation/pages/purchase_orders_page.dart';
import '../../features/purchase_orders/presentation/pages/purchase_order_detail_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/search/presentation/pages/search_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      // Show onboarding on first launch
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_complete') ?? false;
      if (!done && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffPage(),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) => const AuditLogsPage(),
      ),
      GoRoute(
        path: '/registers',
        builder: (context, state) => const RegistersPage(),
      ),
      GoRoute(
        path: '/contracts',
        builder: (context, state) => const ContractsPage(),
      ),
      GoRoute(
        path: '/purchase-orders',
        builder: (context, state) => const PurchaseOrdersPage(),
      ),
      GoRoute(
        path: '/purchase-orders/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PurchaseOrderDetailPage(poId: id);
        },
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsPage(),
      ),

      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return navigationShell;
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return DashboardShell(navigationShell: navigationShell, children: children);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoicesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendors',
                builder: (context, state) => const VendorsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caisse',
                builder: (context, state) => const CaissePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
