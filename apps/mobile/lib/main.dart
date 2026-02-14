import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/services/push_notification_service.dart';
import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before FCM)
  await Firebase.initializeApp();

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

  // Initialize push notification service
  await PushNotificationService.instance.initialize();

  runApp(const JiriSewaApp());
}

class JiriSewaApp extends StatelessWidget {
  const JiriSewaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JiriSewa',
      theme: buildAppTheme(),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _currentSession;

  @override
  void initState() {
    super.initState();
    _currentSession = Supabase.instance.client.auth.currentSession;
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _currentSession = data.session;
        });
        if (data.session != null) {
          _setupPushNotifications();
        }
      },
    );

    if (_currentSession != null) {
      _setupPushNotifications();
    }
  }

  Future<void> _setupPushNotifications() async {
    await PushNotificationService.instance.requestPermissionAndRegister();

    // Avoid duplicate listeners
    _foregroundMessageSub?.cancel();

    _foregroundMessageSub =
        PushNotificationService.instance.onForegroundMessage((message) {
      if (!mounted) return;
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification!.title ?? ''}: ${message.notification!.body ?? ''}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSession != null) {
      return const Scaffold(
        body: Center(child: Text('JiriSewa')),
      );
    }

    return const LoginScreen();
  }
}
