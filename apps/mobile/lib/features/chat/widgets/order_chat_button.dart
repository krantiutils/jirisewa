import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/chat/providers/chat_provider.dart';

/// A button that opens (or creates) a chat conversation for a specific order.
///
/// On tap it calls [ChatRepository.getOrCreateConversation] to find or create
/// the conversation between the current user and [otherUserId], then navigates
/// to the chat detail screen. Shows a loading indicator while the conversation
/// is being resolved.
class OrderChatButton extends ConsumerStatefulWidget {
  /// The order this chat belongs to.
  final String orderId;

  /// The other participant to chat with (e.g. farmer, rider, or consumer).
  final String otherUserId;

  const OrderChatButton({
    super.key,
    required this.orderId,
    required this.otherUserId,
  });

  @override
  ConsumerState<OrderChatButton> createState() => _OrderChatButtonState();
}

class _OrderChatButtonState extends ConsumerState<OrderChatButton> {
  bool _loading = false;

  Future<void> _openChat() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    setState(() => _loading = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversationId = await repo.getOrCreateConversation(
        widget.orderId,
        profile.id,
        widget.otherUserId,
      );

      if (!mounted) return;
      context.push('/chat/$conversationId');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _openChat,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chat_bubble_outline),
      label: const Text('Chat'),
    );
  }
}
