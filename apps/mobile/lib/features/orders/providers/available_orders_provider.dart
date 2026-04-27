import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/orders/repositories/available_orders_repository.dart';

final availableOrdersRepositoryProvider =
    Provider<AvailableOrdersRepository>((ref) {
  return AvailableOrdersRepository(ref.watch(supabaseProvider));
});

final availableOrdersProvider =
    FutureProvider.autoDispose<List<AvailableOrderData>>((ref) async {
  final repo = ref.watch(availableOrdersRepositoryProvider);
  return repo.getAvailableOrders();
});
