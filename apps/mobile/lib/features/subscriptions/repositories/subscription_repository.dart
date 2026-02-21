import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/subscriptions/models/subscription_plan.dart';

class SubscriptionRepository {
  final SupabaseClient _client;
  SubscriptionRepository(this._client);

  // ---------------------------------------------------------------------------
  // Consumer: Browse active plans
  // ---------------------------------------------------------------------------

  /// List all active subscription plans with farmer info and subscriber counts.
  Future<List<SubscriptionPlan>> listActivePlans() async {
    final plans = await _client
        .from('subscription_plans')
        .select('*')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    if (plans.isEmpty) return [];

    // Collect unique farmer IDs and plan IDs.
    final farmerIds = <String>{};
    final planIds = <String>[];
    for (final p in plans) {
      farmerIds.add(p['farmer_id'] as String);
      planIds.add(p['id'] as String);
    }

    // Fetch farmer info and subscriber counts in parallel.
    final farmersFuture = _client
        .from('users')
        .select('id, name, avatar_url, rating_avg, rating_count')
        .inFilter('id', farmerIds.toList());

    final subsFuture = _client
        .from('subscriptions')
        .select('plan_id')
        .inFilter('plan_id', planIds)
        .neq('status', 'cancelled');

    final results = await Future.wait([farmersFuture, subsFuture]);
    final farmers = results[0] as List;
    final subs = results[1] as List;

    // Build farmer map.
    final farmerMap = <String, SubscriptionFarmer>{};
    for (final f in farmers) {
      final map = Map<String, dynamic>.from(f as Map);
      farmerMap[map['id'] as String] = SubscriptionFarmer.fromJson(map);
    }

    // Build subscriber count map.
    final subCounts = <String, int>{};
    for (final s in subs) {
      final planId = (s as Map)['plan_id'] as String;
      subCounts[planId] = (subCounts[planId] ?? 0) + 1;
    }

    return plans.map((p) {
      final map = Map<String, dynamic>.from(p);
      final farmerId = map['farmer_id'] as String;
      final farmer = farmerMap[farmerId] ??
          SubscriptionFarmer(id: farmerId, name: 'Unknown');
      return SubscriptionPlan.fromJson(
        map,
        farmer: farmer,
        subscriberCount: subCounts[map['id'] as String] ?? 0,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Consumer: Manage own subscriptions
  // ---------------------------------------------------------------------------

  /// Get the current consumer's subscriptions with plan and farmer details.
  Future<List<Subscription>> getMySubscriptions(String consumerId) async {
    final subs = await _client
        .from('subscriptions')
        .select(
          '*, subscription_plans(id, name_en, name_ne, description_en, description_ne, price, frequency, items, delivery_day, farmer_id)',
        )
        .eq('consumer_id', consumerId)
        .order('created_at', ascending: false);

    if (subs.isEmpty) return [];

    // Collect farmer IDs from plan data.
    final farmerIds = <String>{};
    for (final s in subs) {
      final plan = s['subscription_plans'] as Map?;
      if (plan != null) {
        farmerIds.add(plan['farmer_id'] as String);
      }
    }

    // Fetch farmer info.
    final farmerMap = <String, SubscriptionFarmer>{};
    if (farmerIds.isNotEmpty) {
      final farmers = await _client
          .from('users')
          .select('id, name, avatar_url, rating_avg, rating_count')
          .inFilter('id', farmerIds.toList());

      for (final f in farmers) {
        final map = Map<String, dynamic>.from(f as Map);
        farmerMap[map['id'] as String] = SubscriptionFarmer.fromJson(map);
      }
    }

    return subs.map((s) {
      final subMap = Map<String, dynamic>.from(s);
      final planData =
          Map<String, dynamic>.from(subMap['subscription_plans'] as Map);
      final farmerId = planData['farmer_id'] as String;
      final farmer = farmerMap[farmerId] ??
          SubscriptionFarmer(id: farmerId, name: 'Unknown');

      final rawItems = planData['items'];
      final items = <SubscriptionPlanItem>[];
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map) {
            items.add(
              SubscriptionPlanItem.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      final planSummary = SubscriptionPlanSummary(
        id: planData['id'] as String,
        nameEn: planData['name_en'] as String? ?? '',
        nameNe: planData['name_ne'] as String? ?? '',
        descriptionEn: planData['description_en'] as String?,
        descriptionNe: planData['description_ne'] as String?,
        price: (planData['price'] as num?)?.toDouble() ?? 0,
        frequency: planData['frequency'] as String? ?? 'weekly',
        items: items,
        deliveryDay: (planData['delivery_day'] as num?)?.toInt() ?? 0,
        farmerId: farmerId,
        farmer: farmer,
      );

      return Subscription.fromJson(subMap, plan: planSummary);
    }).toList();
  }

  /// Subscribe to a plan. Returns the new subscription ID.
  Future<String> subscribeToPlan(
    String consumerId,
    String planId,
    String paymentMethod,
  ) async {
    // Verify plan exists and is active.
    final plan = await _client
        .from('subscription_plans')
        .select('id, max_subscribers, delivery_day, is_active')
        .eq('id', planId)
        .single();

    if (!(plan['is_active'] as bool)) {
      throw Exception('This plan is no longer accepting subscribers');
    }

    // Check subscriber cap.
    final count = await _client
        .from('subscriptions')
        .count()
        .eq('plan_id', planId)
        .neq('status', 'cancelled');

    if (count >= (plan['max_subscribers'] as num).toInt()) {
      throw Exception(
        'This plan has reached its maximum number of subscribers',
      );
    }

    // Check for existing active subscription to same plan.
    final existing = await _client
        .from('subscriptions')
        .select('id')
        .eq('plan_id', planId)
        .eq('consumer_id', consumerId)
        .neq('status', 'cancelled')
        .maybeSingle();

    if (existing != null) {
      throw Exception('You already have an active subscription to this plan');
    }

    final nextDeliveryDate =
        _getNextDeliveryDate((plan['delivery_day'] as num).toInt());

    final result = await _client
        .from('subscriptions')
        .insert({
          'plan_id': planId,
          'consumer_id': consumerId,
          'status': 'active',
          'next_delivery_date': nextDeliveryDate,
          'payment_method': paymentMethod,
        })
        .select('id')
        .single();

    return result['id'] as String;
  }

  /// Pause an active subscription.
  Future<void> pauseSubscription(
    String subscriptionId,
    String consumerId,
  ) async {
    await _client
        .from('subscriptions')
        .update({
          'status': 'paused',
          'paused_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', subscriptionId)
        .eq('consumer_id', consumerId)
        .eq('status', 'active');
  }

  /// Resume a paused subscription. Recalculates next delivery date.
  Future<void> resumeSubscription(
    String subscriptionId,
    String consumerId,
  ) async {
    // Get plan delivery_day to recalculate next delivery.
    final sub = await _client
        .from('subscriptions')
        .select('plan_id, subscription_plans(delivery_day)')
        .eq('id', subscriptionId)
        .eq('consumer_id', consumerId)
        .single();

    final plan = sub['subscription_plans'] as Map;
    final deliveryDay = (plan['delivery_day'] as num).toInt();
    final nextDeliveryDate = _getNextDeliveryDate(deliveryDay);

    await _client
        .from('subscriptions')
        .update({
          'status': 'active',
          'paused_at': null,
          'next_delivery_date': nextDeliveryDate,
        })
        .eq('id', subscriptionId)
        .eq('consumer_id', consumerId)
        .eq('status', 'paused');
  }

  /// Cancel a subscription.
  Future<void> cancelSubscription(
    String subscriptionId,
    String consumerId,
  ) async {
    await _client
        .from('subscriptions')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', subscriptionId)
        .eq('consumer_id', consumerId)
        .neq('status', 'cancelled');
  }

  // ---------------------------------------------------------------------------
  // Farmer: Manage plans
  // ---------------------------------------------------------------------------

  /// Get the farmer's own subscription plans with subscriber counts.
  Future<List<SubscriptionPlan>> getFarmerPlans(String farmerId) async {
    final plans = await _client
        .from('subscription_plans')
        .select('*')
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false);

    if (plans.isEmpty) return [];

    // Get subscriber counts for each plan.
    final planIds = plans.map((p) => p['id'] as String).toList();
    final subs = await _client
        .from('subscriptions')
        .select('plan_id')
        .inFilter('plan_id', planIds)
        .neq('status', 'cancelled');

    final subCounts = <String, int>{};
    for (final s in subs) {
      final planId = s['plan_id'] as String;
      subCounts[planId] = (subCounts[planId] ?? 0) + 1;
    }

    // Get farmer info.
    final farmerData = await _client
        .from('users')
        .select('id, name, avatar_url, rating_avg, rating_count')
        .eq('id', farmerId)
        .single();

    final farmer = SubscriptionFarmer.fromJson(
      Map<String, dynamic>.from(farmerData),
    );

    return plans.map((p) {
      final map = Map<String, dynamic>.from(p);
      return SubscriptionPlan.fromJson(
        map,
        farmer: farmer,
        subscriberCount: subCounts[map['id'] as String] ?? 0,
      );
    }).toList();
  }

  /// Create a new subscription plan. Returns the new plan ID.
  Future<String> createPlan({
    required String farmerId,
    required String nameEn,
    required String nameNe,
    String? descriptionEn,
    String? descriptionNe,
    required double price,
    required String frequency,
    required List<SubscriptionPlanItem> items,
    required int maxSubscribers,
    required int deliveryDay,
  }) async {
    final result = await _client
        .from('subscription_plans')
        .insert({
          'farmer_id': farmerId,
          'name_en': nameEn,
          'name_ne': nameNe,
          'description_en':
              descriptionEn?.isNotEmpty == true ? descriptionEn : null,
          'description_ne':
              descriptionNe?.isNotEmpty == true ? descriptionNe : null,
          'price': price,
          'frequency': frequency,
          'items': items.map((i) => i.toJson()).toList(),
          'max_subscribers': maxSubscribers,
          'delivery_day': deliveryDay,
        })
        .select('id')
        .single();

    return result['id'] as String;
  }

  /// Toggle a plan's active status.
  Future<void> togglePlan(
    String planId,
    String farmerId,
    bool isActive,
  ) async {
    await _client
        .from('subscription_plans')
        .update({'is_active': isActive})
        .eq('id', planId)
        .eq('farmer_id', farmerId);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Calculate the next delivery date for a given delivery day of week.
  static String _getNextDeliveryDate(int deliveryDay) {
    final now = DateTime.now();
    final currentDay = now.weekday % 7; // DateTime weekday: 1=Mon..7=Sun -> 0=Sun
    var daysUntil = deliveryDay - currentDay;
    if (daysUntil <= 0) daysUntil += 7;
    final nextDate = now.add(Duration(days: daysUntil));
    return '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
  }
}
