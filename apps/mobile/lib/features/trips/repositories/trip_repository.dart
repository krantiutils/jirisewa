import 'dart:convert';

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
          'id, origin_name, destination_name, departure_at, status, remaining_capacity_kg, available_capacity_kg',
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

  /// Accept a ping via RPC. Returns the raw RPC result row.
  Future<Map<String, dynamic>?> acceptPing(String pingId) async {
    final result = await _client.rpc(
      'accept_order_ping',
      params: {'p_ping_id': pingId},
    );
    return _firstRpcRow(result);
  }

  /// Decline a ping via RPC. Returns the raw RPC result row.
  Future<Map<String, dynamic>?> declinePing(String pingId) async {
    final result = await _client.rpc(
      'decline_order_ping',
      params: {'p_ping_id': pingId},
    );
    return _firstRpcRow(result);
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

      final activeStops =
          List<Map<String, dynamic>>.from(stopsData).where((s) {
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

      final coords =
          allPoints.map((p) => '${p.longitude},${p.latitude}').join(';');
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

      final lineString = coordsRaw.map((coord) {
        final pair = coord as List<dynamic>;
        return '${(pair[0] as num).toDouble()} ${(pair[1] as num).toDouble()}';
      }).join(',');

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
    } catch (_) {
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
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a PostGIS point from WKT POINT, GeoJSON, or Map format.
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

  Map<String, dynamic>? _firstRpcRow(dynamic result) {
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map<String, dynamic>) return result;
    return null;
  }
}
