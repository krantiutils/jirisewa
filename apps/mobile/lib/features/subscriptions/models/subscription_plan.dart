/// An item included in a subscription plan box.
class SubscriptionPlanItem {
  final String categoryEn;
  final String categoryNe;
  final double approxKg;

  const SubscriptionPlanItem({
    required this.categoryEn,
    required this.categoryNe,
    required this.approxKg,
  });

  factory SubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanItem(
      categoryEn: json['category_en'] as String? ?? '',
      categoryNe: json['category_ne'] as String? ?? '',
      approxKg: (json['approx_kg'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_en': categoryEn,
        'category_ne': categoryNe,
        'approx_kg': approxKg,
      };
}

/// Embedded farmer info attached to a subscription plan.
class SubscriptionFarmer {
  final String id;
  final String name;
  final String? avatarUrl;
  final double ratingAvg;
  final int ratingCount;

  const SubscriptionFarmer({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory SubscriptionFarmer.fromJson(Map<String, dynamic> json) {
    return SubscriptionFarmer(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A subscription plan created by a farmer, with embedded farmer info and
/// subscriber count.
class SubscriptionPlan {
  final String id;
  final String farmerId;
  final String nameEn;
  final String nameNe;
  final String? descriptionEn;
  final String? descriptionNe;
  final double price;
  final String frequency; // weekly, biweekly, monthly
  final List<SubscriptionPlanItem> items;
  final int maxSubscribers;
  final int deliveryDay; // 0=Sunday .. 6=Saturday
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SubscriptionFarmer farmer;
  final int subscriberCount;

  const SubscriptionPlan({
    required this.id,
    required this.farmerId,
    required this.nameEn,
    required this.nameNe,
    this.descriptionEn,
    this.descriptionNe,
    required this.price,
    required this.frequency,
    this.items = const [],
    required this.maxSubscribers,
    required this.deliveryDay,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.farmer,
    this.subscriberCount = 0,
  });

  factory SubscriptionPlan.fromJson(
    Map<String, dynamic> json, {
    required SubscriptionFarmer farmer,
    int subscriberCount = 0,
  }) {
    final rawItems = json['items'];
    final parsedItems = <SubscriptionPlanItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          parsedItems.add(SubscriptionPlanItem.fromJson(item));
        } else if (item is Map) {
          parsedItems.add(
            SubscriptionPlanItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return SubscriptionPlan(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameNe: json['name_ne'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionNe: json['description_ne'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] as String? ?? 'weekly',
      items: parsedItems,
      maxSubscribers: (json['max_subscribers'] as num?)?.toInt() ?? 0,
      deliveryDay: (json['delivery_day'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      farmer: farmer,
      subscriberCount: subscriberCount,
    );
  }

  /// Human-readable label for the delivery day.
  String get deliveryDayLabel {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    if (deliveryDay < 0 || deliveryDay > 6) return 'Unknown';
    return days[deliveryDay];
  }
}

/// Minimal plan info embedded in a consumer subscription.
class SubscriptionPlanSummary {
  final String id;
  final String nameEn;
  final String nameNe;
  final String? descriptionEn;
  final String? descriptionNe;
  final double price;
  final String frequency;
  final List<SubscriptionPlanItem> items;
  final int deliveryDay;
  final String farmerId;
  final SubscriptionFarmer farmer;

  const SubscriptionPlanSummary({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    this.descriptionEn,
    this.descriptionNe,
    required this.price,
    required this.frequency,
    this.items = const [],
    required this.deliveryDay,
    required this.farmerId,
    required this.farmer,
  });
}

/// A consumer's subscription to a plan.
class Subscription {
  final String id;
  final String planId;
  final String consumerId;
  final String status; // active, paused, cancelled
  final String nextDeliveryDate;
  final String paymentMethod; // cash, esewa, khalti
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? pausedAt;
  final DateTime? cancelledAt;
  final SubscriptionPlanSummary plan;

  const Subscription({
    required this.id,
    required this.planId,
    required this.consumerId,
    required this.status,
    required this.nextDeliveryDate,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.pausedAt,
    this.cancelledAt,
    required this.plan,
  });

  factory Subscription.fromJson(
    Map<String, dynamic> json, {
    required SubscriptionPlanSummary plan,
  }) {
    return Subscription(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      consumerId: json['consumer_id'] as String,
      status: json['status'] as String? ?? 'active',
      nextDeliveryDate: json['next_delivery_date'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      pausedAt: json['paused_at'] != null
          ? DateTime.parse(json['paused_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      plan: plan,
    );
  }
}
