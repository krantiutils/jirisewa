import 'package:supabase_flutter/supabase_flutter.dart';

class ProduceRepository {
  final SupabaseClient _client;
  ProduceRepository(this._client);

  Future<List<Map<String, dynamic>>> listActiveListings(
      {int limit = 30}) async {
    final result = await _client
        .from('produce_listings')
        .select(
            'id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality_id, created_at, municipalities!municipality_id(name_en, name_ne)')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> listFarmerListings(String farmerId,
      {int limit = 20}) async {
    final result = await _client
        .from('produce_listings')
        .select(
            'id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality_id, created_at, municipalities!municipality_id(name_en, name_ne)')
        .eq('farmer_id', farmerId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> listPendingPickups(String farmerId,
      {int limit = 20}) async {
    final result = await _client
        .from('order_items')
        .select(
            'id, order_id, listing_id, quantity_kg, subtotal, pickup_status')
        .eq('farmer_id', farmerId)
        .eq('pickup_status', 'pending_pickup')
        .order('id')
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Fetch a single produce listing with joined farmer, category, and
  /// municipality data for the detail screen.
  Future<Map<String, dynamic>?> getListingDetail(String listingId) async {
    final result = await _client
        .from('produce_listings')
        .select(
          '*, users!farmer_id(id, name, rating_avg, rating_count), '
          'produce_categories!category_id(name_en, name_ne, icon), '
          'municipalities!municipality_id(name_en, name_ne)',
        )
        .eq('id', listingId)
        .maybeSingle();
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> fetchOrdersForIds(
      List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final result = await _client
        .from('orders')
        .select('id, status, delivery_address, rider_id, rider_trip_id')
        .inFilter('id', orderIds);
    final map = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(result)) {
      final id = row['id'] as String?;
      if (id != null) map[id] = row;
    }
    return map;
  }
}
