/// A chat conversation linked to an order, with optional UI-enrichment fields
/// populated from joins/aggregation (last message, unread count).
class Conversation {
  final String id;
  final String orderId;
  final List<String> participantIds;
  final DateTime createdAt;

  // UI fields populated from joins / aggregation:
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final String? lastMessageType;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.orderId,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageAt,
    this.lastMessageType,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // participant_ids comes from Supabase as List<dynamic> (text[] column).
    final rawIds = json['participant_ids'] as List<dynamic>? ?? const [];
    final participantIds =
        rawIds.map((e) => e.toString()).toList(growable: false);

    return Conversation(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      participantIds: participantIds,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageContent: json['last_message_content'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageType: json['last_message_type'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'participant_ids': participantIds,
        'created_at': createdAt.toIso8601String(),
        'last_message_content': lastMessageContent,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'last_message_type': lastMessageType,
        'unread_count': unreadCount,
      };
}
