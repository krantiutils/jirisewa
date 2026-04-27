import 'package:supabase_flutter/supabase_flutter.dart';

/// A single line item within a farmer's order.
class FarmerOrderItem {
  final String id;
  final String listingId;
  final double quantityKg;
  final double pricePerKg;
  final double subtotal;
  final String pickupStatus;
  final String? listingName;

  const FarmerOrderItem({
    required this.id,
    required this.listingId,
    required this.quantityKg,
    required this.pricePerKg,
    required this.subtotal,
    required this.pickupStatus,
    this.listingName,
  });
}

/// An order as seen from the farmer's perspective, grouped from order_items.
class FarmerOrder {
  final String id;
  final String status;
  final DateTime createdAt;
  final String? deliveryAddress;
  final double totalPrice;
  final String? consumerName;
  final String? riderName;
  final List<FarmerOrderItem> items;
  final double farmerSubtotal;

  const FarmerOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    this.deliveryAddress,
    required this.totalPrice,
    this.consumerName,
    this.riderName,
    required this.items,
    required this.farmerSubtotal,
  });
}

/// Repository for fetching orders relevant to a specific farmer.
class FarmerOrdersRepository {
  final SupabaseClient _client;

  FarmerOrdersRepository(this._client);

  /// Fetch all order items for this farmer, with deep joins to orders, consumers, and riders,
  /// then group by order into [FarmerOrder] objects.
  Future<List<FarmerOrder>> getFarmerOrders(String farmerId) async {
    final result = await _client
        .from('order_items')
        .select('''
          id, order_id, listing_id, quantity_kg, price_per_kg, subtotal, pickup_status,
          listing:produce_listings!order_items_listing_id_fkey(name_en),
          order:orders!order_items_order_id_fkey(id, status, created_at, delivery_address, total_price,
            consumer:users!orders_consumer_id_fkey(name),
            rider:users!orders_rider_id_fkey(name))
        ''')
        .eq('farmer_id', farmerId);

    // Group items by order_id.
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in List<Map<String, dynamic>>.from(result)) {
      final orderId = item['order_id'] as String;
      grouped.putIfAbsent(orderId, () => []);
      grouped[orderId]!.add(item);
    }

    final orders = <FarmerOrder>[];

    for (final entry in grouped.entries) {
      final itemMaps = entry.value;

      // Supabase joins may return a List or a single object depending on the relationship.
      final firstItem = itemMaps.first;
      final orderData = firstItem['order'] is List
          ? (firstItem['order'] as List).firstOrNull as Map<String, dynamic>?
          : firstItem['order'] as Map<String, dynamic>?;

      if (orderData == null) continue;

      // Extract consumer and rider names from nested join.
      final consumerData = orderData['consumer'] is List
          ? (orderData['consumer'] as List).firstOrNull as Map<String, dynamic>?
          : orderData['consumer'] as Map<String, dynamic>?;
      final riderData = orderData['rider'] is List
          ? (orderData['rider'] as List).firstOrNull as Map<String, dynamic>?
          : orderData['rider'] as Map<String, dynamic>?;

      final items = itemMaps.map((item) {
        final listing = item['listing'] is List
            ? (item['listing'] as List).firstOrNull as Map<String, dynamic>?
            : item['listing'] as Map<String, dynamic>?;

        return FarmerOrderItem(
          id: item['id'] as String,
          listingId: item['listing_id'] as String,
          quantityKg: (item['quantity_kg'] as num).toDouble(),
          pricePerKg: (item['price_per_kg'] as num).toDouble(),
          subtotal: (item['subtotal'] as num).toDouble(),
          pickupStatus: (item['pickup_status'] as String?) ?? 'pending_pickup',
          listingName: listing?['name_en'] as String?,
        );
      }).toList();

      final farmerSubtotal =
          items.fold<double>(0, (sum, item) => sum + item.subtotal);

      orders.add(FarmerOrder(
        id: orderData['id'] as String,
        status: (orderData['status'] as String?) ?? 'pending',
        createdAt:
            DateTime.parse(orderData['created_at'] as String),
        deliveryAddress: orderData['delivery_address'] as String?,
        totalPrice: (orderData['total_price'] as num).toDouble(),
        consumerName: consumerData?['name'] as String?,
        riderName: riderData?['name'] as String?,
        items: items,
        farmerSubtotal: farmerSubtotal,
      ));
    }

    // Sort by createdAt descending (newest first).
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return orders;
  }
}
