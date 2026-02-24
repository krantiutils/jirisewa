/// An in-app notification delivered to a user.
class AppNotification {
  final String id;

  /// One of: 'order_matched', 'rider_picked_up', 'rider_arriving',
  /// 'order_delivered', 'new_order_for_farmer', 'rider_arriving_for_pickup',
  /// 'new_order_match', 'trip_reminder', 'delivery_confirmed'.
  final String category;
  final String titleEn;
  final String titleNe;
  final String bodyEn;
  final String bodyNe;

  /// Arbitrary JSON payload (may contain `url`, `order_id`, etc.).
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.category,
    required this.titleEn,
    required this.titleNe,
    required this.bodyEn,
    required this.bodyNe,
    this.data = const {},
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      category: json['category'] as String,
      titleEn: json['title_en'] as String? ?? '',
      titleNe: json['title_ne'] as String? ?? '',
      bodyEn: json['body_en'] as String? ?? '',
      bodyNe: json['body_ne'] as String? ?? '',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// A per-category notification preference for a user.
class NotificationPreference {
  final String category;
  final bool enabled;

  const NotificationPreference({
    required this.category,
    required this.enabled,
  });
}
