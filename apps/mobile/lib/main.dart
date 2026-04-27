import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jirisewa_mobile/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/push_notification_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional — push notifications won't work without google-services.json
  // but the rest of the app should run fine.
  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    ),
  );

  runApp(const ProviderScope(child: JiriSewaApp()));
}

class JiriSewaApp extends ConsumerWidget {
  const JiriSewaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final localeAsync = ref.watch(localeProvider);

    // Use the resolved locale, or default to Nepali while loading.
    final locale = localeAsync.valueOrNull ?? const Locale('ne');

    return MaterialApp.router(
      title: 'JiriSewa',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
