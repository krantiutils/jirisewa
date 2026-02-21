import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/subscriptions/models/subscription_plan.dart';
import 'package:jirisewa_mobile/features/subscriptions/repositories/subscription_repository.dart';

/// Provider for the SubscriptionRepository, wired to the Supabase client.
final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseProvider));
});

/// All active subscription plans (for consumer browsing).
final activeSubscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.listActivePlans();
});

/// The current consumer's subscriptions.
final mySubscriptionsProvider =
    FutureProvider.autoDispose<List<Subscription>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.getMySubscriptions(profile.id);
});

/// The current farmer's subscription plans.
final farmerSubscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.getFarmerPlans(profile.id);
});
