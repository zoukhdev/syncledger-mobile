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

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

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
