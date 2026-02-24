import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

class HomeDashboardData {
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> nearbyProduce;
  final List<Map<String, dynamic>> upcomingTrips;
  final List<Map<String, dynamic>> matchedOrders;
  final List<Map<String, dynamic>> activeListings;
  final List<Map<String, dynamic>> pendingOrders;

  const HomeDashboardData({
    this.recentOrders = const [],
    this.nearbyProduce = const [],
    this.upcomingTrips = const [],
    this.matchedOrders = const [],
    this.activeListings = const [],
    this.pendingOrders = const [],
  });
}

final homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  final client = ref.read(supabaseProvider);
  final profile = ref.watch(userProfileProvider);
  final role = ref.watch(activeRoleProvider);

  if (profile == null) return const HomeDashboardData();

  final userId = profile.id;

  switch (role) {
    case 'consumer':
      final orders = await client
          .from('orders')
          .select('id, status, total_price, delivery_fee, created_at')
          .eq('consumer_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      final produce = await client
          .from('produce_listings')
          .select(
              'id, name_en, name_ne, price_per_kg, available_qty_kg, photos')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(6);
      return HomeDashboardData(
        recentOrders: List<Map<String, dynamic>>.from(orders),
        nearbyProduce: List<Map<String, dynamic>>.from(produce),
      );

    case 'rider':
      final trips = await client
          .from('rider_trips')
          .select(
              'id, origin_name, destination_name, departure_at, status, remaining_capacity_kg')
          .eq('rider_id', userId)
          .inFilter('status', ['scheduled', 'in_transit'])
          .order('departure_at')
          .limit(5);
      final orders = await client
          .from('orders')
          .select(
              'id, status, total_price, delivery_fee, delivery_address, created_at')
          .eq('rider_id', userId)
          .inFilter('status', ['matched', 'picked_up', 'in_transit'])
          .order('created_at', ascending: false)
          .limit(5);
      return HomeDashboardData(
        upcomingTrips: List<Map<String, dynamic>>.from(trips),
        matchedOrders: List<Map<String, dynamic>>.from(orders),
      );

    case 'farmer':
      final listings = await client
          .from('produce_listings')
          .select('id, name_en, name_ne, price_per_kg, available_qty_kg')
          .eq('farmer_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);
      final pendingItems = await client
          .from('order_items')
          .select(
              'id, quantity_kg, price_per_kg, subtotal, pickup_status, order_id')
          .eq('farmer_id', userId)
          .eq('pickup_status', 'pending_pickup')
          .limit(5);
      return HomeDashboardData(
        activeListings: List<Map<String, dynamic>>.from(listings),
        pendingOrders: List<Map<String, dynamic>>.from(pendingItems),
      );

    default:
      return const HomeDashboardData();
  }
});
