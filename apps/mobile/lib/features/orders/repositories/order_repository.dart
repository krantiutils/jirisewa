import 'package:supabase_flutter/supabase_flutter.dart';

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
}
