import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/business/models/business_profile.dart';
import 'package:jirisewa_mobile/features/business/models/bulk_order.dart';
import 'package:jirisewa_mobile/features/business/repositories/business_repository.dart';

/// Provider for the BusinessRepository, wired to the Supabase client.
final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseProvider));
});

/// The current user's business profile (null if not registered).
final businessProfileProvider =
    FutureProvider.autoDispose<BusinessProfile?>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return null;

  final repo = ref.watch(businessRepositoryProvider);
  return repo.getBusinessProfile(profile.id);
});

/// Bulk orders for the current business.
final bulkOrdersProvider =
    FutureProvider.autoDispose<List<BulkOrder>>((ref) async {
  final bizProfile = await ref.watch(businessProfileProvider.future);
  if (bizProfile == null) return const [];

  final repo = ref.watch(businessRepositoryProvider);
  return repo.listBulkOrders(bizProfile.id);
});

/// A single bulk order by ID.
final bulkOrderDetailProvider =
    FutureProvider.autoDispose.family<BulkOrder?, String>((ref, orderId) async {
  final repo = ref.watch(businessRepositoryProvider);
  return repo.getBulkOrder(orderId);
});

/// Bulk orders containing items from the current farmer.
final farmerBulkOrdersProvider =
    FutureProvider.autoDispose<List<BulkOrder>>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return const [];

  final repo = ref.watch(businessRepositoryProvider);
  return repo.listFarmerBulkOrders(profile.id);
});
