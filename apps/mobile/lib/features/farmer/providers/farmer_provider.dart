import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/farmer/repositories/farmer_repository.dart';

final farmerRepositoryProvider = Provider<FarmerRepository>((ref) {
  return FarmerRepository(ref.watch(supabaseProvider));
});

final categoriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(farmerRepositoryProvider);
  return repo.getCategories();
});

final farmerListingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, listingId) async {
  final repo = ref.watch(farmerRepositoryProvider);
  return repo.getListing(listingId);
});
