import 'package:supabase_flutter/supabase_flutter.dart';

class HubInfo {
  final String id;
  final String nameEn;
  final String nameNe;
  final String address;
  final String hubType;

  const HubInfo({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.address,
    required this.hubType,
  });

  factory HubInfo.fromMap(Map<String, dynamic> m) => HubInfo(
        id: m['id'] as String,
        nameEn: (m['name_en'] as String?) ?? '',
        nameNe: (m['name_ne'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        hubType: (m['hub_type'] as String?) ?? 'origin',
      );
}

class DropoffInfo {
  final String id;
  final String hubId;
  final String hubName;
  final String listingId;
  final String listingName;
  final String farmerId;
  final String farmerName;
  final double quantityKg;
  final String lotCode;
  final String status;
  final DateTime droppedAt;
  final DateTime? receivedAt;
  final DateTime? dispatchedAt;
  final DateTime expiresAt;

  const DropoffInfo({
    required this.id,
    required this.hubId,
    required this.hubName,
    required this.listingId,
    required this.listingName,
    required this.farmerId,
    required this.farmerName,
    required this.quantityKg,
    required this.lotCode,
    required this.status,
    required this.droppedAt,
    required this.receivedAt,
    required this.dispatchedAt,
    required this.expiresAt,
  });

  factory DropoffInfo.fromMap(Map<String, dynamic> m) {
    final hub = m['hub'] as Map<String, dynamic>?;
    final listing = m['listing'] as Map<String, dynamic>?;
    final farmer = m['farmer'] as Map<String, dynamic>?;
    return DropoffInfo(
      id: m['id'] as String,
      hubId: m['hub_id'] as String,
      hubName: (hub?['name_en'] as String?) ?? '',
      listingId: m['listing_id'] as String,
      listingName: (listing?['name_en'] as String?) ?? '',
      farmerId: m['farmer_id'] as String,
      farmerName: (farmer?['name'] as String?) ?? '',
      quantityKg: (m['quantity_kg'] as num).toDouble(),
      lotCode: m['lot_code'] as String,
      status: m['status'] as String,
      droppedAt: DateTime.parse(m['dropped_at'] as String),
      receivedAt: m['received_at'] != null
          ? DateTime.parse(m['received_at'] as String)
          : null,
      dispatchedAt: m['dispatched_at'] != null
          ? DateTime.parse(m['dispatched_at'] as String)
          : null,
      expiresAt: DateTime.parse(m['expires_at'] as String),
    );
  }
}

class HubRepository {
  final SupabaseClient _client;
  HubRepository(this._client);

  /// Active origin / transit hubs (those that accept farmer dropoffs).
  Future<List<HubInfo>> listOriginHubs() async {
    final result = await _client
        .from('pickup_hubs')
        .select('id, name_en, name_ne, address, hub_type')
        .eq('is_active', true)
        .inFilter('hub_type', ['origin', 'transit'])
        .order('name_en');
    return List<Map<String, dynamic>>.from(result)
        .map(HubInfo.fromMap)
        .toList();
  }

  /// Listings owned by the calling farmer. RLS restricts to the user's own.
  Future<List<Map<String, dynamic>>> listMyActiveListings(String farmerId) async {
    final result = await _client
        .from('produce_listings')
        .select('id, name_en, pickup_mode')
        .eq('farmer_id', farmerId)
        .eq('is_active', true)
        .order('name_en');
    return List<Map<String, dynamic>>.from(result);
  }

  /// Record a hub dropoff. Returns { dropoff_id, lot_code, expires_at }.
  Future<Map<String, dynamic>> recordDropoff({
    required String hubId,
    required String listingId,
    required double quantityKg,
  }) async {
    final result = await _client.rpc('record_hub_dropoff_v1', params: {
      'p_hub_id': hubId,
      'p_listing_id': listingId,
      'p_quantity_kg': quantityKg,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// The farmer's own dropoffs.
  Future<List<DropoffInfo>> listMyDropoffs(String farmerId) async {
    final result = await _client
        .from('hub_dropoffs')
        .select(
          'id, hub_id, listing_id, farmer_id, quantity_kg, lot_code, status, '
          'dropped_at, received_at, dispatched_at, expires_at, '
          'hub:pickup_hubs!hub_dropoffs_hub_id_fkey(name_en), '
          'listing:produce_listings!hub_dropoffs_listing_id_fkey(name_en), '
          'farmer:users!hub_dropoffs_farmer_id_fkey(name)',
        )
        .eq('farmer_id', farmerId)
        .order('dropped_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(result)
        .map(DropoffInfo.fromMap)
        .toList();
  }

  /// The hub assigned to the calling user as operator (single hub for v1).
  Future<HubInfo?> getMyOperatedHub(String operatorId) async {
    final result = await _client
        .from('pickup_hubs')
        .select('id, name_en, name_ne, address, hub_type')
        .eq('operator_id', operatorId)
        .eq('is_active', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (result == null) return null;
    return HubInfo.fromMap(Map<String, dynamic>.from(result));
  }

  Future<List<DropoffInfo>> listHubInventory(String hubId) async {
    final result = await _client
        .from('hub_dropoffs')
        .select(
          'id, hub_id, listing_id, farmer_id, quantity_kg, lot_code, status, '
          'dropped_at, received_at, dispatched_at, expires_at, '
          'hub:pickup_hubs!hub_dropoffs_hub_id_fkey(name_en), '
          'listing:produce_listings!hub_dropoffs_listing_id_fkey(name_en), '
          'farmer:users!hub_dropoffs_farmer_id_fkey(name)',
        )
        .eq('hub_id', hubId)
        .order('dropped_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(result)
        .map(DropoffInfo.fromMap)
        .toList();
  }

  Future<void> markReceived(String dropoffId) async {
    await _client.rpc('mark_dropoff_received_v1', params: {
      'p_dropoff_id': dropoffId,
    });
  }

  Future<void> markSpoiled(String dropoffId, {String? notes}) async {
    await _client.rpc('mark_dropoff_spoiled_v1', params: {
      'p_dropoff_id': dropoffId,
      'p_notes': notes,
    });
  }

  Future<void> dispatchToTrip(String dropoffId, String riderTripId) async {
    await _client.rpc('dispatch_dropoff_v1', params: {
      'p_dropoff_id': dropoffId,
      'p_rider_trip_id': riderTripId,
    });
  }
}
