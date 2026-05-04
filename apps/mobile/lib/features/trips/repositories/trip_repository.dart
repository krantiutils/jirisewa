import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';

class TripRepository {
  final SupabaseClient _client;
  TripRepository(this._client);

  /// Fetch rider trips ordered by departure date (newest first).
  Future<List<Map<String, dynamic>>> listTrips(
    String riderId, {
    int limit = 20,
  }) async {
    final result = await _client
        .from('rider_trips')
        .select(
          'id, origin, origin_name, destination, destination_name, departure_at, status, remaining_capacity_kg, available_capacity_kg',
        )
        .eq('rider_id', riderId)
        .order('departure_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Fetch active orders assigned to this rider.
  Future<List<Map<String, dynamic>>> listRiderOrders(
    String riderId, {
    int limit = 40,
  }) async {
    final result = await _client
        .from('orders')
        .select('id, rider_trip_id, status, delivery_address, total_price')
        .eq('rider_id', riderId)
        .inFilter('status', ['matched', 'picked_up', 'in_transit', 'pending'])
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Fetch pending (active, non-expired) pings for this rider.
  Future<List<Map<String, dynamic>>> listPendingPings(
    String riderId, {
    int limit = 60,
  }) async {
    final result = await _client
        .from('order_pings')
        .select(
          'id, trip_id, pickup_locations, delivery_location, estimated_earnings, detour_distance_m, status, expires_at',
        )
        .eq('rider_id', riderId)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Accept a ping using direct table operations (first-accept-wins).
  ///
  /// Mirrors the web app's `acceptPing` server action:
  /// 1. Verify ping is still pending and not expired.
  /// 2. Atomically update the order from 'pending' to 'matched'.
  /// 3. Mark ping as accepted, expire other pings for the same order.
  /// 4. Deduct trip capacity.
  ///
  /// Returns `{'success': true, 'message': ..., 'trip_id': ...}` or
  /// `{'success': false, 'message': ...}`.
  Future<Map<String, dynamic>> acceptPing(String pingId) async {
    // 1. Fetch ping details
    final ping = await _client
        .from('order_pings')
        .select()
        .eq('id', pingId)
        .maybeSingle();

    if (ping == null) {
      return {'success': false, 'message': 'Ping not found'};
    }

    if ((ping['status'] as String?) != 'pending') {
      return {'success': false, 'message': 'Ping already responded to'};
    }

    final expiresAt = DateTime.tryParse(ping['expires_at'] as String? ?? '');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      await _client
          .from('order_pings')
          .update({'status': 'expired'})
          .eq('id', pingId);
      return {'success': false, 'message': 'Ping has expired'};
    }

    final orderId = ping['order_id'] as String;
    final riderId = ping['rider_id'] as String;
    final tripId = ping['trip_id'] as String;

    // 2. Atomically match the order (first-accept-wins)
    final matchedRows = await _client
        .from('orders')
        .update({
          'status': 'matched',
          'rider_id': riderId,
          'rider_trip_id': tripId,
        })
        .eq('id', orderId)
        .eq('status', 'pending')
        .select('id');

    if ((matchedRows as List).isEmpty) {
      // Race condition — another rider got it first
      await _client
          .from('order_pings')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', pingId);
      return {
        'success': false,
        'message': 'Order already matched to another rider',
      };
    }

    // 3. Mark ping as accepted
    await _client
        .from('order_pings')
        .update({
          'status': 'accepted',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', pingId);

    // 4. Expire other pending pings for this order
    await _client
        .from('order_pings')
        .update({'status': 'expired'})
        .eq('order_id', orderId)
        .eq('status', 'pending')
        .neq('id', pingId);

    // 5. Deduct trip capacity
    final trip = await _client
        .from('rider_trips')
        .select('remaining_capacity_kg')
        .eq('id', tripId)
        .maybeSingle();

    if (trip != null) {
      final remaining =
          (trip['remaining_capacity_kg'] as num?)?.toDouble() ?? 0;
      final weight = (ping['total_weight_kg'] as num?)?.toDouble() ?? 0;
      final newCapacity = (remaining - weight).clamp(0, double.infinity);
      await _client
          .from('rider_trips')
          .update({'remaining_capacity_kg': newCapacity})
          .eq('id', tripId);
    }

    return {'success': true, 'message': 'Order accepted', 'trip_id': tripId};
  }

  /// Decline a ping using direct table update.
  ///
  /// Returns `{'success': true, 'message': ...}` or
  /// `{'success': false, 'message': ...}`.
  Future<Map<String, dynamic>> declinePing(String pingId) async {
    final ping = await _client
        .from('order_pings')
        .select('id, status')
        .eq('id', pingId)
        .maybeSingle();

    if (ping == null) {
      return {'success': false, 'message': 'Ping not found'};
    }

    if ((ping['status'] as String?) != 'pending') {
      return {'success': false, 'message': 'Ping already responded to'};
    }

    await _client
        .from('order_pings')
        .update({
          'status': 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', pingId);

    return {'success': true, 'message': 'Ping declined'};
  }

  /// Create a new rider trip with PostGIS geography data.
  ///
  /// Inserts into `rider_trips` with origin/destination as WKT POINTs,
  /// optional LINESTRING route from OSRM, and municipality IDs.
  /// Returns the created trip row or throws on failure.
  Future<Map<String, dynamic>> createTrip({
    required String riderId,
    required LatLng origin,
    required String originName,
    required LatLng destination,
    required String destinationName,
    required DateTime departureAt,
    required double availableCapacityKg,
    List<LatLng>? routeCoordinates,
    String? originMunicipalityId,
    String? destinationMunicipalityId,
  }) async {
    final insertData = <String, dynamic>{
      'rider_id': riderId,
      'origin': 'POINT(${origin.longitude} ${origin.latitude})',
      'origin_name': originName,
      'destination': 'POINT(${destination.longitude} ${destination.latitude})',
      'destination_name': destinationName,
      'departure_at': departureAt.toUtc().toIso8601String(),
      'available_capacity_kg': availableCapacityKg,
      'remaining_capacity_kg': availableCapacityKg,
      'status': 'scheduled',
    };

    if (routeCoordinates != null && routeCoordinates.length >= 2) {
      final lineString = routeCoordinates
          .map((p) => '${p.longitude} ${p.latitude}')
          .join(',');
      insertData['route'] = 'LINESTRING($lineString)';
    }

    if (originMunicipalityId != null) {
      insertData['origin_municipality_id'] = originMunicipalityId;
    }
    if (destinationMunicipalityId != null) {
      insertData['destination_municipality_id'] = destinationMunicipalityId;
    }

    final result = await _client
        .from('rider_trips')
        .insert(insertData)
        .select()
        .single();

    return Map<String, dynamic>.from(result);
  }

  /// Fetch OSRM driving route between two points.
  /// Returns route coordinates as [LatLng] list, or null on failure.
  Future<List<LatLng>?> fetchOsrmRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final coords =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final uri = Uri.parse(
        '$osrmBaseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordsRaw = geometry['coordinates'] as List<dynamic>;
      if (coordsRaw.length < 2) return null;

      return coordsRaw.map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();
    } catch (e) {
      debugPrint('fetchOsrmRoute failed: $e');
      return null;
    }
  }

  /// Full OSRM route recalculation for a trip from its active stops.
  /// Returns true if the route was successfully recalculated and persisted.
  Future<bool> recalculateTripRoute(String tripId) async {
    try {
      final tripRow = await _client
          .from('rider_trips')
          .select('id, destination, rider_id')
          .eq('id', tripId)
          .maybeSingle();
      if (tripRow == null) return false;

      final destination = parsePoint(tripRow['destination']);
      if (destination == null) return false;

      final stopsData = await _client
          .from('trip_stops')
          .select('id, location, sequence_order, completed')
          .eq('trip_id', tripId)
          .order('sequence_order', ascending: true);

      final activeStops = List<Map<String, dynamic>>.from(stopsData).where((s) {
        return s['completed'] != true;
      }).toList();
      if (activeStops.isEmpty) return false;

      final latestLoc = await _client
          .from('rider_location_log')
          .select('location')
          .eq('trip_id', tripId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      LatLng? start = parsePoint(latestLoc?['location']);
      start ??= parsePoint(activeStops.first['location']);
      if (start == null) return false;

      final stopPoints = <LatLng>[];
      for (final stop in activeStops) {
        final point = parsePoint(stop['location']);
        if (point != null) stopPoints.add(point);
      }
      if (stopPoints.isEmpty) return false;

      final allPoints = <LatLng>[start, ...stopPoints, destination];
      if (allPoints.length < 2) return false;

      final coords = allPoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final uri = Uri.parse(
        '$osrmBaseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return false;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return false;
      final route = routes.first as Map<String, dynamic>;

      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordsRaw = geometry['coordinates'] as List<dynamic>;
      if (coordsRaw.length < 2) return false;

      final lineString = coordsRaw
          .map((coord) {
            final pair = coord as List<dynamic>;
            return '${(pair[0] as num).toDouble()} ${(pair[1] as num).toDouble()}';
          })
          .join(',');

      final routeWkt = 'LINESTRING($lineString)';
      final totalDistanceKm =
          ((route['distance'] as num?)?.toDouble() ?? 0) / 1000;
      final durationMinutes =
          (((route['duration'] as num?)?.toDouble() ?? 0) / 60).round();

      await _client
          .from('rider_trips')
          .update({
            'route': routeWkt,
            'total_distance_km': totalDistanceKm,
            'estimated_duration_minutes': durationMinutes,
            'total_stops': activeStops.length,
          })
          .eq('id', tripId);

      final legs = route['legs'] as List<dynamic>? ?? const [];
      var cumulativeSeconds = 0.0;
      for (var i = 0; i < activeStops.length; i++) {
        if (i >= legs.length) break;
        final leg = legs[i] as Map<String, dynamic>;
        cumulativeSeconds += (leg['duration'] as num?)?.toDouble() ?? 0;
        final eta = DateTime.now().add(
          Duration(seconds: cumulativeSeconds.round()),
        );
        await _client
            .from('trip_stops')
            .update({
              'sequence_order': i,
              'estimated_arrival': eta.toIso8601String(),
            })
            .eq('id', activeStops[i]['id'] as String);
      }

      return true;
    } catch (e) {
      debugPrint('recalculateTripRoute($tripId) failed: $e');
      return false;
    }
  }

  /// Subscribe to real-time ping updates (inserts and updates) for a rider.
  /// Returns a [RealtimeChannel] that the caller must clean up via [removeChannel].
  RealtimeChannel subscribeToPings(
    String riderId, {
    required void Function(Map<String, dynamic> newRecord) onEvent,
  }) {
    return _client
        .channel('mobile-pings-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_pings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (payload) {
            onEvent(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'order_pings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (payload) {
            onEvent(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  /// Remove a realtime channel subscription.
  void removeChannel(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Trip Detail — single trip, stops, and matched orders
  // ---------------------------------------------------------------------------

  /// Fetch a single trip with all fields.
  Future<Map<String, dynamic>?> getTrip(String tripId) async {
    final result = await _client
        .from('rider_trips')
        .select()
        .eq('id', tripId)
        .maybeSingle();
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  /// Fetch ordered stops for a trip.
  Future<List<Map<String, dynamic>>> listTripStops(String tripId) async {
    final result = await _client
        .from('trip_stops')
        .select()
        .eq('trip_id', tripId)
        .order('sequence_order', ascending: true);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Fetch orders matched to this trip with their items.
  Future<List<Map<String, dynamic>>> listOrdersByTrip(String tripId) async {
    final result = await _client
        .from('orders')
        .select('*, order_items(*, produce_listings(name_en, name_ne))')
        .eq('rider_trip_id', tripId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  // ---------------------------------------------------------------------------
  // Trip lifecycle actions
  // ---------------------------------------------------------------------------

  /// Start a scheduled trip (scheduled -> in_transit).
  Future<void> startTrip(String tripId) async {
    await _client
        .from('rider_trips')
        .update({'status': 'in_transit'})
        .eq('id', tripId)
        .eq('status', 'scheduled');
  }

  /// Complete an in-transit trip (in_transit -> completed).
  Future<void> completeTrip(String tripId) async {
    await _client
        .from('rider_trips')
        .update({'status': 'completed'})
        .eq('id', tripId)
        .eq('status', 'in_transit');
  }

  /// Cancel a scheduled trip (scheduled -> cancelled).
  Future<void> cancelTrip(String tripId) async {
    await _client
        .from('rider_trips')
        .update({'status': 'cancelled'})
        .eq('id', tripId)
        .eq('status', 'scheduled');
  }

  // ---------------------------------------------------------------------------
  // Per-farmer order actions
  // ---------------------------------------------------------------------------

  /// Confirm pickup for a specific farmer's items in an order.
  Future<void> confirmFarmerPickup(String orderId, String farmerId) async {
    await _client
        .from('order_items')
        .update({'pickup_status': 'picked_up'})
        .eq('order_id', orderId)
        .eq('farmer_id', farmerId);
  }

  /// Mark a specific farmer's items as unavailable in an order.
  Future<void> markItemsUnavailable(String orderId, String farmerId) async {
    await _client
        .from('order_items')
        .update({'pickup_status': 'unavailable'})
        .eq('order_id', orderId)
        .eq('farmer_id', farmerId);
  }

  /// Transition an order to in_transit status (matched -> in_transit).
  Future<void> startDelivery(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'in_transit'})
        .eq('id', orderId)
        .eq('status', 'matched');
  }

  // ---------------------------------------------------------------------------
  // Stop reordering
  // ---------------------------------------------------------------------------

  /// Batch-update sequence_order values for trip stops.
  ///
  /// [stopIds] should be the stop IDs in the desired order. Each stop's
  /// sequence_order will be set to its index in the list.
  Future<void> reorderStops(String tripId, List<String> stopIds) async {
    if (stopIds.isEmpty) return;
    await Future.wait([
      for (var i = 0; i < stopIds.length; i++)
        _client
            .from('trip_stops')
            .update({'sequence_order': i})
            .eq('id', stopIds[i])
            .eq('trip_id', tripId),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a PostGIS point from WKT POINT, EWKB hex, GeoJSON, or Map format.
  /// Supabase returns geography columns as EWKB hex by default — see
  /// `0101000020E6100000<lng-LE><lat-LE>` (50 hex chars total).
  static LatLng? parsePoint(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      final pointMatch = RegExp(
        r'^POINT\(([-\d.]+)\s+([-\d.]+)\)$',
      ).firstMatch(trimmed);
      if (pointMatch != null) {
        final lng = double.tryParse(pointMatch.group(1)!);
        final lat = double.tryParse(pointMatch.group(2)!);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      if (trimmed.length >= 50 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
        try {
          final bytes = Uint8List(trimmed.length ~/ 2);
          for (var i = 0; i < bytes.length; i++) {
            bytes[i] = int.parse(
              trimmed.substring(i * 2, i * 2 + 2),
              radix: 16,
            );
          }
          final view = ByteData.view(bytes.buffer);
          final lng = view.getFloat64(9, Endian.little);
          final lat = view.getFloat64(17, Endian.little);
          return LatLng(lat, lng);
        } catch (_) {
          // Fall through to JSON / null.
        }
      }
      if (trimmed.startsWith('{')) {
        try {
          final decoded = json.decode(trimmed);
          return parsePoint(decoded);
        } catch (_) {
          return null;
        }
      }
    }

    if (value is Map) {
      if (value['coordinates'] is List) {
        final coords = value['coordinates'] as List;
        if (coords.length >= 2) {
          final lng = (coords[0] as num?)?.toDouble();
          final lat = (coords[1] as num?)?.toDouble();
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }
}
