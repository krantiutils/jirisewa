import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/cart/models/cart.dart';
import 'package:jirisewa_mobile/features/checkout/providers/delivery_fee_provider.dart';

// ---------------------------------------------------------------------------
// Place-order input / result models
// ---------------------------------------------------------------------------

/// Input data required to place a new order.
class PlaceOrderInput {
  final String consumerId;
  final List<CartItem> items;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;

  /// One of: 'cash', 'esewa', 'khalti', 'connectips'.
  final String paymentMethod;
  final DeliveryFeeEstimate feeEstimate;

  const PlaceOrderInput({
    required this.consumerId,
    required this.items,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.paymentMethod,
    required this.feeEstimate,
  });
}

/// Result returned after successfully placing an order.
class PlaceOrderResult {
  final String orderId;

  /// Non-null for digital payments (eSewa / Khalti / connectIPS).
  /// Contains gateway-specific fields needed to redirect the user.
  final Map<String, dynamic>? paymentData;

  const PlaceOrderResult({required this.orderId, this.paymentData});
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class OrderRepository {
  final SupabaseClient _client;
  OrderRepository(this._client);

  /// Fetch orders for a user based on their role.
  /// Riders see orders assigned to them; consumers see orders they placed.
  Future<List<Map<String, dynamic>>> listOrders(
    String userId,
    String role, {
    int limit = 20,
  }) async {
    final query = _client
        .from('orders')
        .select('id, status, total_price, delivery_fee, delivery_address, created_at');

    // Farmers currently see orders they placed as consumers.
    // Farmer-specific order view (orders containing their produce) is planned for a future task.
    List<dynamic> result;
    if (role == 'rider') {
      result = await query
          .eq('rider_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
    } else {
      result = await query
          .eq('consumer_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
    }

    return List<Map<String, dynamic>>.from(result);
  }

  /// Fetch a single order with all fields.
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    final result = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();

    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  /// Fetch order items with joined produce_listings data.
  Future<List<Map<String, dynamic>>> listOrderItems(String orderId) async {
    final result = await _client
        .from('order_items')
        .select('*, produce_listings(name_en, name_ne)')
        .eq('order_id', orderId);

    return List<Map<String, dynamic>>.from(result);
  }

  /// Get the latest rider location for a trip from rider_location_log.
  Future<Map<String, dynamic>?> getLatestRiderLocation(String tripId) async {
    final result = await _client
        .from('rider_location_log')
        .select('location, recorded_at')
        .eq('trip_id', tripId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return result;
  }

  /// Subscribe to real-time rider location updates for a trip.
  /// Returns a RealtimeChannel that the caller is responsible for unsubscribing.
  RealtimeChannel subscribeToRiderLocation(
    String tripId,
    String orderId, {
    required void Function(Map<String, dynamic> newRecord) onInsert,
  }) {
    return _client
        .channel('order_tracking_${orderId}_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rider_location_log',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            onInsert(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Remove a realtime channel subscription.
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // -------------------------------------------------------------------------
  // Order actions
  // -------------------------------------------------------------------------

  /// Cancel a pending or matched order.
  /// Routes through cancel_order_v1 — atomic SECURITY DEFINER RPC that also
  /// refunds farmer payouts, expires pending pings, and marks digital payment
  /// transactions REFUNDED. Mirrors the web cancelOrder action.
  Future<bool> cancelOrder(String orderId) async {
    await _client.rpc('cancel_order_v1', params: {'p_order_id': orderId});
    return true;
  }

  /// Consumer confirms delivery.
  /// Routes through confirm_delivery_v1 — atomic SECURITY DEFINER RPC that
  /// settles payouts, marks items delivery_confirmed, releases digital escrow,
  /// and (via the status trigger) notifies the rider.
  Future<bool> confirmDelivery(String orderId) async {
    await _client.rpc('confirm_delivery_v1', params: {'p_order_id': orderId});
    return true;
  }

  // -------------------------------------------------------------------------
  // Place order
  // -------------------------------------------------------------------------

  /// Create a new order with items, farmer payouts, and (for digital payments)
  /// a payment gateway transaction record.
  ///
  /// Returns the order ID and optional payment redirect data.
  /// Throws on validation failure or database error (cleans up partial state).
  Future<PlaceOrderResult> placeOrder(PlaceOrderInput input) async {
    if (input.items.isEmpty) {
      throw ArgumentError('Cannot place an order with an empty cart');
    }
    const validMethods = {'cash', 'esewa', 'khalti', 'connectips'};
    if (!validMethods.contains(input.paymentMethod)) {
      throw ArgumentError('Invalid payment method: ${input.paymentMethod}');
    }

    // place_order_v1 is a SECURITY DEFINER RPC that performs the multi-table
    // insert atomically (orders + order_items + farmer_payouts + per-gateway
    // transaction row). It enforces consumer_id = auth.uid() and re-derives
    // line-item prices from produce_listings, so we don't have to trust the
    // client-side cart for pricing.
    final response = await _client.rpc(
      'place_order_v1',
      params: {
        'p_delivery_address': input.deliveryAddress,
        'p_delivery_lat': input.deliveryLat,
        'p_delivery_lng': input.deliveryLng,
        'p_payment_method': input.paymentMethod,
        'p_delivery_fee': _round2(input.feeEstimate.totalFee),
        'p_delivery_fee_base': _round2(input.feeEstimate.baseFee),
        'p_delivery_fee_distance': _round2(input.feeEstimate.distanceFee),
        'p_delivery_fee_weight': _round2(input.feeEstimate.weightFee),
        'p_delivery_distance_km': input.feeEstimate.distanceKm,
        'p_items': input.items
            .map((item) => {
                  'listing_id': item.listingId,
                  'quantity_kg': item.quantityKg,
                })
            .toList(),
      },
    );

    final result = response as Map<String, dynamic>;
    final orderId = result['order_id'] as String;
    final paymentData = result['payment_data'] as Map<String, dynamic>?;

    return PlaceOrderResult(orderId: orderId, paymentData: paymentData);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Round a double to 2 decimal places.
  static double _round2(double value) => (value * 100).round() / 100;
}
