import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles background messages when the app is terminated or in background.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

/// Service for managing Firebase Cloud Messaging push notifications.
/// Handles token registration, foreground/background message handling,
/// and device token persistence in Supabase.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  String? _currentToken;
  bool _initialized = false;

  /// Initialize FCM and register background handler.
  /// Call this once during app startup, after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('FCM initialization failed: $e');
    }
  }

  /// Request notification permission and register the FCM token with Supabase.
  /// Call this after the user has authenticated.
  Future<void> requestPermissionAndRegister() async {
    if (_messaging == null) return;

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('Push notification permission denied');
      return;
    }

    await _registerToken();
    _listenForTokenRefresh();
  }

  /// Register current FCM token with the user_devices table in Supabase.
  Future<void> _registerToken() async {
    try {
      final token = await _messaging!.getToken();
      if (token == null) return;

      _currentToken = token;

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      await supabase.from('user_devices').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': platform,
          'is_active': true,
        },
        onConflict: 'user_id,fcm_token',
      );

      debugPrint('FCM token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Listen for token refreshes and re-register when they occur.
  void _listenForTokenRefresh() {
    _messaging!.onTokenRefresh.listen((newToken) async {
      if (_currentToken != null && _currentToken != newToken) {
        // Deactivate old token
        try {
          final supabase = Supabase.instance.client;
          final userId = supabase.auth.currentUser?.id;
          if (userId != null) {
            await supabase
                .from('user_devices')
                .update({'is_active': false})
                .eq('user_id', userId)
                .eq('fcm_token', _currentToken!);
          }
        } catch (e) {
          debugPrint('Failed to deactivate old token: $e');
        }
      }
      _currentToken = newToken;
      await _registerToken();
    });
  }

  /// Set up foreground message handler.
  /// Returns the stream of messages received while the app is in foreground.
  void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Set up handler for when user taps a notification (app was in background).
  void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Check if the app was opened from a terminated state via notification tap.
  Future<RemoteMessage?> getInitialMessage() async {
    return _messaging?.getInitialMessage();
  }

  /// Deactivate the current device token (call on sign out).
  Future<void> unregisterToken() async {
    if (_currentToken == null) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('user_devices')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('fcm_token', _currentToken!);

      _currentToken = null;
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }
  }
}
