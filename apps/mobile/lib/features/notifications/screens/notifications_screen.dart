import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/notifications/models/app_notification.dart';
import 'package:jirisewa_mobile/features/notifications/providers/notification_provider.dart';

/// Paginated notification list screen.
///
/// Displays all notifications for the current user, newest first. Tapping a
/// notification marks it as read and navigates to the relevant screen if the
/// notification payload contains a `url` field. A "Mark all read" button in the
/// header clears all unread indicators at once.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final profile = ref.watch(userProfileProvider);
    final hasUnread = (unreadCountAsync.valueOrNull ?? 0) > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  if (hasUnread)
                    TextButton(
                      onPressed: () async {
                        if (profile == null) return;
                        final repo =
                            ref.read(notificationRepositoryProvider);
                        await repo.markAllRead(profile.id);
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadNotificationCountProvider);
                      },
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  IconButton(
                    onPressed: () =>
                        context.push(AppRoutes.notificationPreferences),
                    tooltip: 'Notification preferences',
                    icon: const Icon(Icons.settings_outlined, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load notifications: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(notificationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (notifications) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                    await ref.read(notificationsProvider.future);
                  },
                  child: notifications.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.3),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: notifications.length,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemBuilder: (ctx, i) => _NotificationTile(
                            notification: notifications[i],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = !notification.read;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () async {
          final profile = ref.read(userProfileProvider);
          if (profile == null) return;

          final repo = ref.read(notificationRepositoryProvider);
          await repo.markRead(notification.id, profile.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);

          if (!context.mounted) return;

          final url = notification.data['url'] as String?;
          if (url != null && url.isNotEmpty) {
            context.push(url);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withAlpha(25),
                child: Icon(
                  _categoryIcon(notification.category),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.titleEn,
                            style: TextStyle(
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _timeAgo(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread
                                ? AppColors.primary
                                : Colors.grey[500],
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.bodyEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread
                            ? AppColors.foreground
                            : Colors.grey[600],
                        fontWeight:
                            isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'order_matched':
      case 'order_delivered':
      case 'new_order_for_farmer':
      case 'delivery_confirmed':
        return Icons.receipt_outlined;
      case 'rider_picked_up':
      case 'rider_arriving':
      case 'rider_arriving_for_pickup':
      case 'new_order_match':
      case 'trip_reminder':
        return Icons.two_wheeler_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';

    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(msgDay).inDays;

    if (dayDiff == 1) return 'Yesterday';
    if (dayDiff < 7) return '${dayDiff}d ago';

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
