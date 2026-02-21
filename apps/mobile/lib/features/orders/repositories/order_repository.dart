import 'dart:math';

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
  // Place order
  // -------------------------------------------------------------------------

  /// Create a new order with items, farmer payouts, and (for digital payments)
  /// a payment gateway transaction record.
  ///
  /// Returns the order ID and optional payment redirect data.
  Future<PlaceOrderResult> placeOrder(PlaceOrderInput input) async {
    // 1. Calculate monetary totals
    final totalPrice =
        _round2(input.items.fold(0.0, (sum, item) => sum + item.subtotal));
    final deliveryFee = _round2(input.feeEstimate.totalFee);
    final grandTotal = _round2(totalPrice + deliveryFee);

    // 2. Insert order row
    final orderRow = await _client
        .from('orders')
        .insert({
          'consumer_id': input.consumerId,
          'status': 'pending',
          'delivery_address': input.deliveryAddress,
          'delivery_location':
              'POINT(${input.deliveryLng} ${input.deliveryLat})',
          'total_price': totalPrice,
          'delivery_fee': deliveryFee,
          'delivery_fee_base': _round2(input.feeEstimate.baseFee),
          'delivery_fee_distance': _round2(input.feeEstimate.distanceFee),
          'delivery_fee_weight': _round2(input.feeEstimate.weightFee),
          'delivery_distance_km': input.feeEstimate.distanceKm,
          'payment_method': input.paymentMethod,
          'payment_status': 'pending',
        })
        .select('id')
        .single();

    final orderId = orderRow['id'] as String;

    // 3. Fetch pickup locations from produce_listings for each unique listing
    final listingIds =
        input.items.map((item) => item.listingId).toSet().toList();
    final listings = await _client
        .from('produce_listings')
        .select('id, location')
        .inFilter('id', listingIds);
    final listingLocationMap = <String, String?>{};
    for (final listing in listings) {
      listingLocationMap[listing['id'] as String] =
          listing['location'] as String?;
    }

    // 4. Assign pickup_sequence per farmer group (1-indexed)
    final farmerGroups = <String, int>{};
    var farmerIndex = 0;
    for (final item in input.items) {
      if (!farmerGroups.containsKey(item.farmerId)) {
        farmerIndex++;
        farmerGroups[item.farmerId] = farmerIndex;
      }
    }

    // 5. Insert order_items
    final itemRows = input.items
        .map((item) => <String, dynamic>{
              'order_id': orderId,
              'listing_id': item.listingId,
              'farmer_id': item.farmerId,
              'quantity_kg': item.quantityKg,
              'price_per_kg': item.pricePerKg,
              'subtotal': _round2(item.subtotal),
              'pickup_location': listingLocationMap[item.listingId],
              'pickup_sequence': farmerGroups[item.farmerId],
              'pickup_status': 'pending_pickup',
            })
        .toList();

    await _client.from('order_items').insert(itemRows);

    // 6. Insert farmer_payouts (one per unique farmer)
    final payoutsByFarmer = <String, double>{};
    for (final item in input.items) {
      payoutsByFarmer[item.farmerId] =
          (payoutsByFarmer[item.farmerId] ?? 0) + item.subtotal;
    }

    final payoutRows = payoutsByFarmer.entries
        .map((e) => <String, dynamic>{
              'order_id': orderId,
              'farmer_id': e.key,
              'amount': _round2(e.value),
              'status': 'pending',
            })
        .toList();

    await _client.from('farmer_payouts').insert(payoutRows);

    // 7. Create payment transaction for digital payments
    Map<String, dynamic>? paymentData;

    if (input.paymentMethod == 'esewa') {
      final txnUuid = _generateUuid();
      await _client.from('esewa_transactions').insert({
        'order_id': orderId,
        'transaction_uuid': txnUuid,
        'product_code': 'EPAYTEST', // TODO: use env config
        'amount': totalPrice,
        'tax_amount': 0,
        'service_charge': 0,
        'delivery_charge': deliveryFee,
        'total_amount': grandTotal,
        'status': 'PENDING',
      });
      paymentData = {
        'orderId': orderId,
        'transactionUuid': txnUuid,
        'gateway': 'esewa',
      };
    } else if (input.paymentMethod == 'khalti') {
      final purchaseOrderId = 'KH-$orderId';
      final amountPaisa = (grandTotal * 100).round();
      await _client.from('khalti_transactions').insert({
        'order_id': orderId,
        'purchase_order_id': purchaseOrderId,
        'amount_paisa': amountPaisa,
        'total_amount': grandTotal,
        'status': 'PENDING',
      });
      paymentData = {
        'orderId': orderId,
        'purchaseOrderId': purchaseOrderId,
        'amountPaisa': amountPaisa,
        'gateway': 'khalti',
      };
    } else if (input.paymentMethod == 'connectips') {
      final txnId = 'CI-$orderId';
      final referenceId = 'REF-$orderId';
      final amountPaisa = (grandTotal * 100).round();
      await _client.from('connectips_transactions').insert({
        'order_id': orderId,
        'txn_id': txnId,
        'reference_id': referenceId,
        'amount_paisa': amountPaisa,
        'total_amount': grandTotal,
        'status': 'PENDING',
      });
      paymentData = {
        'orderId': orderId,
        'txnId': txnId,
        'referenceId': referenceId,
        'amountPaisa': amountPaisa,
        'gateway': 'connectips',
      };
    }

    return PlaceOrderResult(orderId: orderId, paymentData: paymentData);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Round a double to 2 decimal places.
  static double _round2(double value) => (value * 100).round() / 100;

  /// Generate a UUID-like string for payment transaction identifiers.
  ///
  /// Combines a millisecond timestamp with random hex digits to produce a
  /// unique 32-character identifier (formatted with hyphens like a UUID v4).
  static String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = Random();
    final hex = StringBuffer();
    hex.write(now.toRadixString(16).padLeft(12, '0'));
    for (var i = hex.length; i < 32; i++) {
      hex.write(rng.nextInt(16).toRadixString(16));
    }
    final h = hex.toString().substring(0, 32);
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-'
        '${h.substring(20, 32)}';
  }
}
