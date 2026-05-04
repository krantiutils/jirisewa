import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jirisewa_mobile/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/providers/auth_provider.dart';
import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/push_notification_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/locale_provider.dart';
import 'package:jirisewa_mobile/features/notifications/providers/notification_provider.dart';

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
      defaultValue: 'https://khetbata.xyz/_supabase',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
    ),
  );

  runApp(const ProviderScope(child: JiriSewaApp()));
}

class JiriSewaApp extends ConsumerStatefulWidget {
  const JiriSewaApp({super.key});

  @override
  ConsumerState<JiriSewaApp> createState() => _JiriSewaAppState();
}

class _JiriSewaAppState extends ConsumerState<JiriSewaApp> {
  bool _deepLinksWired = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  @override
  void dispose() {
    _foregroundSub?.cancel();
    PushNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final localeAsync = ref.watch(localeProvider);

    // Wire deep-link handling once, after the router is available.
    if (!_deepLinksWired) {
      _deepLinksWired = true;
      try {
        PushNotificationService.instance.setupDeepLinkHandling(router);
      } catch (e) {
        debugPrint('FCM deep link wiring skipped: $e');
      }
    }

    // Listen for auth state changes — register FCM token on sign-in,
    // unregister on sign-out. The push service is safe to call even when
    // Firebase isn't configured (it no-ops if _messaging is null).
    ref.listen<Session?>(currentSessionProvider, (prev, next) async {
      if (prev == null && next != null) {
        try {
          await PushNotificationService.instance.requestPermissionAndRegister();
        } catch (e) {
          debugPrint('FCM token registration skipped: $e');
        }
      } else if (prev != null && next == null) {
        try {
          await PushNotificationService.instance.unregisterToken();
        } catch (e) {
          debugPrint('FCM token unregistration skipped: $e');
        }
      }
    });

    // Foreground messages: refresh notification badge + show a snackbar.
    _foregroundSub ??= PushNotificationService.instance.onForegroundMessage((
      message,
    ) {
      // Refresh in-app notification list/badge so the bell updates immediately.
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(notificationsProvider);

      final notif = message.notification;
      final messengerKey = _messengerKey;
      if (notif == null || messengerKey.currentState == null) return;

      messengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(notif.title ?? notif.body ?? 'New notification'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              final type = message.data['type'] as String?;
              final orderId = message.data['order_id'] as String?;
              if (type == 'ping') {
                router.go('/trips');
              } else if (orderId != null) {
                router.go('/orders/$orderId');
              }
            },
          ),
        ),
      );
    });

    final locale = localeAsync.valueOrNull ?? const Locale('ne');

    return MaterialApp.router(
      title: 'JiriSewa',
      theme: buildAppTheme(),
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
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

final _messengerKey = GlobalKey<ScaffoldMessengerState>();
