import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/farmer/repositories/farmer_orders_repository.dart';

final farmerOrdersRepositoryProvider =
    Provider<FarmerOrdersRepository>((ref) {
  return FarmerOrdersRepository(ref.watch(supabaseProvider));
});

final farmerOrdersProvider =
    FutureProvider.autoDispose<List<FarmerOrder>>((ref) async {
  final repo = ref.watch(farmerOrdersRepositoryProvider);
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return const [];
  return repo.getFarmerOrders(profile.id);
});
