import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/chat/providers/chat_provider.dart';

/// A chat icon button with an unread-count badge overlay.
///
/// The badge is only visible when the user has unread messages. Tapping
/// navigates to the conversations list at `/chat`. Designed for use as an
/// AppBar action or in any header row.
class ChatBadge extends ConsumerWidget {
  /// Icon size for the chat bubble icon.
  final double iconSize;

  /// Optional override for the icon color.
  final Color? iconColor;

  const ChatBadge({
    super.key,
    this.iconSize = 24,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadChatCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return IconButton(
      onPressed: () => context.push(AppRoutes.chat),
      tooltip: 'Chat',
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
          Icons.chat_bubble_outline,
          size: iconSize,
          color: iconColor ?? AppColors.foreground,
        ),
      ),
    );
  }
}
