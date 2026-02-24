import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/orders/repositories/order_repository.dart';

/// Data class for the orders list screen.
class OrdersData {
  final List<Map<String, dynamic>> orders;

  const OrdersData({this.orders = const []});
}

/// Data class for the order detail screen.
class OrderDetailData {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;

  const OrderDetailData({required this.order, this.items = const []});
}

/// Provider for the OrderRepository, wired to the Supabase client.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseProvider));
});

/// Fetches the list of orders for the current user based on their active role.
final ordersListProvider =
    FutureProvider.autoDispose<OrdersData>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final profile = ref.watch(userProfileProvider);
  final role = ref.watch(activeRoleProvider);

  if (profile == null) {
    return const OrdersData();
  }

  final orders = await repo.listOrders(profile.id, role);
  return OrdersData(orders: orders);
});

/// Fetches a single order with its items, keyed by orderId.
final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetailData, String>(
  (ref, orderId) async {
    final repo = ref.watch(orderRepositoryProvider);

    final order = await repo.getOrder(orderId);
    if (order == null) {
      throw Exception('Order not found');
    }

    final items = await repo.listOrderItems(orderId);
    return OrderDetailData(order: order, items: items);
  },
);
