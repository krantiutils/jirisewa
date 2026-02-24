import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/notifications/providers/notification_provider.dart';

/// A notification bell icon button with an unread-count badge overlay.
///
/// The badge is only visible when the user has unread notifications. Tapping
/// navigates to the notifications screen at `/notifications`. Designed for use
/// as an AppBar action or in any header row.
class NotificationBell extends ConsumerWidget {
  /// Icon size for the bell icon.
  final double iconSize;

  /// Optional override for the icon color.
  final Color? iconColor;

  const NotificationBell({
    super.key,
    this.iconSize = 24,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return IconButton(
      onPressed: () => context.push(AppRoutes.notifications),
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        child: Icon(
          Icons.notifications_outlined,
          size: iconSize,
          color: iconColor ?? AppColors.foreground,
        ),
      ),
    );
  }
}
