import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/notifications/models/app_notification.dart';

/// All known notification categories. Used to fill in default preferences for
/// categories that don't yet have a row in `notification_preferences`.
const _allCategories = [
  'order_matched',
  'rider_picked_up',
  'rider_arriving',
  'order_delivered',
  'new_order_for_farmer',
  'rider_arriving_for_pickup',
  'new_order_match',
  'trip_reminder',
  'delivery_confirmed',
];

class NotificationRepository {
  final SupabaseClient _client;
  NotificationRepository(this._client);

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Fetch paginated notifications for [userId], newest first.
  Future<List<AppNotification>> listNotifications(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Get the count of unread notifications for [userId].
  Future<int> getUnreadCount(String userId) async {
    final count = await _client
        .from('notifications')
        .count()
        .eq('user_id', userId)
        .eq('read', false);

    return count;
  }

  /// Mark a single notification as read.
  Future<void> markRead(String notificationId, String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  /// Mark all unread notifications as read for [userId].
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  // ---------------------------------------------------------------------------
  // Notification preferences
  // ---------------------------------------------------------------------------

  /// Get notification preferences for [userId].
  ///
  /// Returns all 9 categories. Categories without a stored row default to
  /// enabled = true.
  Future<List<NotificationPreference>> getPreferences(String userId) async {
    final rows = await _client
        .from('notification_preferences')
        .select('category, enabled')
        .eq('user_id', userId);

    // Build a map of stored preferences keyed by category.
    final stored = <String, bool>{};
    for (final row in rows) {
      stored[row['category'] as String] = row['enabled'] as bool;
    }

    // Return full list, defaulting to enabled for missing categories.
    return _allCategories
        .map((cat) => NotificationPreference(
              category: cat,
              enabled: stored[cat] ?? true,
            ))
        .toList();
  }

  /// Update (upsert) a single notification preference.
  Future<void> updatePreference(
    String userId,
    String category,
    bool enabled,
  ) async {
    await _client.from('notification_preferences').upsert(
      {
        'user_id': userId,
        'category': category,
        'enabled': enabled,
      },
      onConflict: 'user_id,category',
    );
  }
}
