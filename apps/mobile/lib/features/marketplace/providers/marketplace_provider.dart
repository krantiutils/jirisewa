import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/marketplace/repositories/produce_repository.dart';

class MarketplaceData {
  final List<Map<String, dynamic>> listings;
  final List<Map<String, dynamic>> pendingPickups;
  final Map<String, Map<String, dynamic>> ordersById;

  const MarketplaceData({
    this.listings = const [],
    this.pendingPickups = const [],
    this.ordersById = const {},
  });
}

final produceRepositoryProvider = Provider<ProduceRepository>((ref) {
  return ProduceRepository(ref.read(supabaseProvider));
});

final marketplaceDataProvider =
    FutureProvider.autoDispose<MarketplaceData>((ref) async {
  final repo = ref.read(produceRepositoryProvider);
  final profile = ref.watch(userProfileProvider);
  final role = ref.watch(activeRoleProvider);

  if (role == 'farmer' && profile != null) {
    final farmerId = profile.id;
    final listings = await repo.listFarmerListings(farmerId);
    final pendingPickups = await repo.listPendingPickups(farmerId);

    final orderIds = pendingPickups
        .map((item) => item['order_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final ordersById = await repo.fetchOrdersForIds(orderIds);

    return MarketplaceData(
      listings: listings,
      pendingPickups: pendingPickups,
      ordersById: ordersById,
    );
  }

  // Consumer / default: all active listings
  final listings = await repo.listActiveListings();
  return MarketplaceData(listings: listings);
});
