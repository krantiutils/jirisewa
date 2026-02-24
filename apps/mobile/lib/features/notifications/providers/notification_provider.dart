import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/notifications/models/app_notification.dart';
import 'package:jirisewa_mobile/features/notifications/repositories/notification_repository.dart';

/// Provider for the NotificationRepository, wired to the Supabase client.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseProvider));
});

/// Fetches the list of notifications for the current user (newest first).
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.listNotifications(profile.id);
});

/// Unread notification count for the current user. Useful for badge display.
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return 0;

  return repo.getUnreadCount(profile.id);
});

/// Notification preferences for the current user (all 9 categories).
final notificationPreferencesProvider =
    FutureProvider.autoDispose<List<NotificationPreference>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.getPreferences(profile.id);
});
