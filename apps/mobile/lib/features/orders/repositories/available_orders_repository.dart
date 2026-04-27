import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Summary of an item within an available order.
class OrderItemSummary {
  final String nameEn;
  final double quantityKg;
  final String farmerName;

  const OrderItemSummary({
    required this.nameEn,
    required this.quantityKg,
    required this.farmerName,
  });
}

/// A farmer pickup location deduced from order items.
class PickupLocation {
  final String farmerName;
  final double lat;
  final double lng;

  const PickupLocation({
    required this.farmerName,
    required this.lat,
    required this.lng,
  });
}

/// Represents an order that is available for a rider to accept.
class AvailableOrderData {
  final String id;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final double totalPrice;
  final double deliveryFee;
  final double totalWeightKg;
  final DateTime createdAt;
  final List<PickupLocation> pickupLocations;
  final List<OrderItemSummary> items;

  const AvailableOrderData({
    required this.id,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.totalPrice,
    required this.deliveryFee,
    required this.totalWeightKg,
    required this.createdAt,
    required this.pickupLocations,
    required this.items,
  });
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class AvailableOrdersRepository {
  final SupabaseClient _client;
  AvailableOrdersRepository(this._client);

  /// Fetch pending orders that have no rider assigned and no parent order.
  Future<List<AvailableOrderData>> getAvailableOrders() async {
    final result = await _client
        .from('orders')
        .select(
          'id, delivery_address, delivery_location, total_price, delivery_fee, created_at, '
          'items:order_items('
          'quantity_kg, '
          'listing:produce_listings!order_items_listing_id_fkey(name_en, location), '
          'farmer:users!order_items_farmer_id_fkey(name)'
          ')',
        )
        .eq('status', 'pending')
        .isFilter('rider_id', null)
        .isFilter('parent_order_id', null)
        .order('created_at', ascending: false)
        .limit(50);

    final rows = List<Map<String, dynamic>>.from(result);
    final orders = <AvailableOrderData>[];

    for (final row in rows) {
      final deliveryCoords = _parsePoint(row['delivery_location']);
      final deliveryLat = deliveryCoords?.$1 ?? 0.0;
      final deliveryLng = deliveryCoords?.$2 ?? 0.0;

      // Skip orders with no valid delivery location.
      if (deliveryLat == 0 && deliveryLng == 0) continue;

      final rawItems = row['items'] as List<dynamic>? ?? [];

      final items = <OrderItemSummary>[];
      final pickupMap = <String, PickupLocation>{};
      double totalWeight = 0;

      for (final rawItem in rawItems) {
        final item = rawItem as Map<String, dynamic>;
        final qty = (item['quantity_kg'] as num?)?.toDouble() ?? 0;
        totalWeight += qty;

        final listing = item['listing'] as Map<String, dynamic>?;
        final farmer = item['farmer'] as Map<String, dynamic>?;
        final nameEn = (listing?['name_en'] as String?) ?? 'Unknown';
        final farmerName = (farmer?['name'] as String?) ?? 'Unknown Farmer';

        items.add(OrderItemSummary(
          nameEn: nameEn,
          quantityKg: qty,
          farmerName: farmerName,
        ));

        // Deduplicate pickup locations by farmer name.
        if (!pickupMap.containsKey(farmerName) && listing != null) {
          final locCoords = _parsePoint(listing['location']);
          if (locCoords != null) {
            pickupMap[farmerName] = PickupLocation(
              farmerName: farmerName,
              lat: locCoords.$1,
              lng: locCoords.$2,
            );
          }
        }
      }

      orders.add(AvailableOrderData(
        id: row['id'] as String,
        deliveryAddress: (row['delivery_address'] as String?) ?? '',
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        totalPrice: (row['total_price'] as num?)?.toDouble() ?? 0,
        deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
        totalWeightKg: totalWeight,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        pickupLocations: pickupMap.values.toList(),
        items: items,
      ));
    }

    return orders;
  }

  /// Accept an available order by creating a trip and matching the order.
  ///
  /// Returns the newly created trip ID.
  Future<String> acceptOrder({
    required String orderId,
    required String riderId,
    required double originLat,
    required double originLng,
    required String originName,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
    required double capacityKg,
  }) async {
    // 1. Create a rider trip.
    final tripRow = await _client
        .from('rider_trips')
        .insert({
          'rider_id': riderId,
          'origin': 'POINT($originLng $originLat)',
          'origin_name': originName,
          'destination': 'POINT($destinationLng $destinationLat)',
          'destination_name': destinationName,
          'departure_at': DateTime.now().toUtc().toIso8601String(),
          'available_capacity_kg': capacityKg,
          'remaining_capacity_kg': capacityKg,
          'status': 'scheduled',
        })
        .select('id')
        .single();

    final tripId = tripRow['id'] as String;

    // 2. Match the order to this rider + trip (optimistic lock on status).
    await _client
        .from('orders')
        .update({
          'rider_id': riderId,
          'rider_trip_id': tripId,
          'status': 'matched',
        })
        .eq('id', orderId)
        .eq('status', 'pending');

    return tripId;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a WKT POINT string into (lat, lng).
  ///
  /// WKT format: `POINT(<lng> <lat>)`
  static (double, double)? _parsePoint(dynamic value) {
    if (value == null) return null;
    if (value is! String) return null;

    final match = RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(value);
    if (match == null) return null;

    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;

    return (lat, lng);
  }
}
