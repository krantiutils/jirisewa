import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/chat/models/chat_message.dart';
import 'package:jirisewa_mobile/features/chat/models/conversation.dart';
import 'package:jirisewa_mobile/features/chat/repositories/chat_repository.dart';

/// Provider for the ChatRepository, wired to the Supabase client.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseProvider));
});

/// Fetches the list of conversations for the current user, enriched with
/// last-message content and unread counts.
final conversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.listConversations(profile.id);
});

/// Streams messages for a specific conversation via Supabase Realtime.
/// Emits the initial message list and pushes updates on each new insert.
final messagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, conversationId) {
    final repo = ref.watch(chatRepositoryProvider);
    return repo.messagesStream(conversationId);
  },
);

/// Total unread chat message count across all conversations for the current
/// user. Useful for badge display.
final unreadChatCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return 0;

  return repo.getTotalUnreadCount(profile.id);
});
