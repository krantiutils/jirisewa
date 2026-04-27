import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/chat/models/chat_message.dart';
import 'package:jirisewa_mobile/features/chat/models/conversation.dart';

class ChatRepository {
  final SupabaseClient _client;
  ChatRepository(this._client);

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  /// Get or create a conversation for an order between the current user and
  /// another participant. Participant IDs are sorted for consistent storage so
  /// the same pair never creates duplicate conversations.
  Future<String> getOrCreateConversation(
    String orderId,
    String currentUserId,
    String otherUserId,
  ) async {
    final participantIds = [currentUserId, otherUserId]..sort();

    // Try to find existing conversation.
    final existing = await _client
        .from('chat_conversations')
        .select('id')
        .eq('order_id', orderId)
        .contains('participant_ids', participantIds)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    // Create new conversation.
    try {
      final created = await _client
          .from('chat_conversations')
          .insert({
            'order_id': orderId,
            'participant_ids': participantIds,
          })
          .select('id')
          .single();

      return created['id'] as String;
    } on PostgrestException catch (e) {
      // Handle race condition — another client created it first (unique violation).
      if (e.code == '23505') {
        final raceResult = await _client
            .from('chat_conversations')
            .select('id')
            .eq('order_id', orderId)
            .contains('participant_ids', participantIds)
            .single();
        return raceResult['id'] as String;
      }
      rethrow;
    }
  }

  /// List conversations for [userId] with last-message and unread-count data.
  ///
  /// Because PostgREST has limited subquery support we fetch the base
  /// conversations first, then enrich each with a latest-message query and an
  /// unread-count query.
  Future<List<Conversation>> listConversations(String userId) async {
    final rows = await _client
        .from('chat_conversations')
        .select('*')
        .contains('participant_ids', [userId])
        .order('created_at', ascending: false);

    // Enrich each conversation with last message + unread count in parallel.
    final enriched = await Future.wait(rows.map((row) async {
      final convId = row['id'] as String;

      final lastMsgFuture = _client
          .from('chat_messages')
          .select('content, message_type, created_at')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final unreadCountFuture = _client
          .from('chat_messages')
          .count()
          .eq('conversation_id', convId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);

      final results = await (lastMsgFuture, unreadCountFuture).wait;
      final lastMsg = results.$1;
      final unreadCount = results.$2;

      final data = Map<String, dynamic>.from(row);
      data['last_message_content'] = lastMsg?['content'];
      data['last_message_at'] = lastMsg?['created_at'];
      data['last_message_type'] = lastMsg?['message_type'];
      data['unread_count'] = unreadCount;

      return Conversation.fromJson(data);
    }));

    // Sort by last-message time descending, falling back to created_at.
    enriched.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return enriched;
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  /// Send a message in a conversation.
  Future<ChatMessage> sendMessage(
    String conversationId,
    String senderId,
    String content, {
    String messageType = 'text',
  }) async {
    final row = await _client
        .from('chat_messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
          'message_type': messageType,
        })
        .select()
        .single();

    return ChatMessage.fromJson(row);
  }

  /// Fetch paginated messages for a conversation (newest first, cursor-based).
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeId,
  }) async {
    var query = _client
        .from('chat_messages')
        .select()
        .eq('conversation_id', conversationId);

    if (beforeId != null) {
      // Cursor pagination: fetch the timestamp of the cursor message, then
      // query for messages created before that timestamp.
      final cursorRow = await _client
          .from('chat_messages')
          .select('created_at')
          .eq('id', beforeId)
          .maybeSingle();

      if (cursorRow != null) {
        query = query.lt('created_at', cursorRow['created_at'] as String);
      }
    }

    final rows =
        await query.order('created_at', ascending: true).limit(limit);

    return rows
        .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Stream messages for a conversation via Supabase Realtime.
  ///
  /// Emits an initial list from [getMessages] and then yields an updated list
  /// whenever a new message is inserted into the conversation.
  Stream<List<ChatMessage>> messagesStream(
    String conversationId, {
    int limit = 50,
  }) {
    final controller = StreamController<List<ChatMessage>>();
    var messages = <ChatMessage>[];
    RealtimeChannel? channel;

    () async {
      try {
        // 1. Fetch initial messages.
        messages = await getMessages(conversationId, limit: limit);
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(messages));
        }

        // 2. Subscribe to new inserts on chat_messages for this conversation.
        channel = _client
            .channel('chat_messages_$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (payload) {
                final newMsg = ChatMessage.fromJson(
                  Map<String, dynamic>.from(payload.newRecord),
                );
                messages = [...messages, newMsg];
                if (!controller.isClosed) {
                  controller.add(List.unmodifiable(messages));
                }
              },
            )
            .subscribe();
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }();

    controller.onCancel = () {
      if (channel != null) {
        _client.removeChannel(channel!);
      }
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Read status
  // ---------------------------------------------------------------------------

  /// Mark all messages in a conversation as read (messages not sent by
  /// [currentUserId] where read_at is still null).
  Future<void> markConversationRead(
    String conversationId,
    String currentUserId,
  ) async {
    await _client
        .from('chat_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .isFilter('read_at', null);
  }

  /// Total unread message count across all of [userId]'s conversations.
  Future<int> getTotalUnreadCount(String userId) async {
    // 1. Get conversation IDs the user participates in.
    final convRows = await _client
        .from('chat_conversations')
        .select('id')
        .contains('participant_ids', [userId]);

    if (convRows.isEmpty) return 0;

    final convIds = convRows.map((r) => r['id'] as String).toList();

    // 2. Count unread messages across those conversations.
    final count = await _client
        .from('chat_messages')
        .count()
        .inFilter('conversation_id', convIds)
        .neq('sender_id', userId)
        .isFilter('read_at', null);

    return count;
  }

  // ---------------------------------------------------------------------------
  // Image upload
  // ---------------------------------------------------------------------------

  /// Upload chat image bytes to Supabase Storage and return the public URL.
  Future<String> uploadChatImage(
    String userId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('chat-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final publicUrl =
        _client.storage.from('chat-images').getPublicUrl(path);

    return publicUrl;
  }

  // ---------------------------------------------------------------------------
  // Audio upload
  // ---------------------------------------------------------------------------

  /// Upload chat audio bytes to Supabase Storage and return the public URL.
  Future<String> uploadChatAudio(Uint8List bytes, String conversationId) async {
    final path =
        'chat-audio/$conversationId/${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _client.storage.from('chat-audio').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    final url = _client.storage.from('chat-audio').getPublicUrl(path);
    return url;
  }

  // ---------------------------------------------------------------------------
  // Cleanup helper (for tests / manual use)
  // ---------------------------------------------------------------------------

  /// Remove a realtime channel subscription.
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
