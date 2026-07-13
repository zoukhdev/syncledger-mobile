import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/sync/sync_service.dart';
import 'core/router/app_router.dart';
import 'core/localization/locale_provider.dart';
import 'features/notifications/services/notification_service.dart';

// IMPORTANT: Replace with actual values injected via --dart-define or env file in a real app
const String supabaseUrl = 'https://ptcjueqjulccrmfuyefb.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0Y2p1ZXFqdWxjY3JtZnV5ZWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzNjU0OTYsImV4cCI6MjA5ODk0MTQ5Nn0.eup-MO3CjVBy0dmCkWzE6K-ULCrFU3fsh8Mj7lkS_oo';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Attempt to sync any offline mutations
  try {
    await SyncService.syncOfflineMutations();
  } catch (e) {
    debugPrint('Initial sync failed: $e');
  }

  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification service failed to initialize: $e');
  }

  runApp(const ProviderScope(child: SyncLedgerApp()));
}

class SyncLedgerApp extends ConsumerWidget {
  const SyncLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'SyncLedger',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
