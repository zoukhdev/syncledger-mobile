import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
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
        ],
      ),
    ],
  );
});
