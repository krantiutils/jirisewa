import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/orders/providers/orders_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Represents a rider's GPS position at a point in time.
class RiderLocation {
  final double lat;
  final double lng;
  final double? speedKmh;
  final DateTime recordedAt;

  const RiderLocation({
    required this.lat,
    required this.lng,
    this.speedKmh,
    required this.recordedAt,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Streams live rider GPS positions for the given [orderId].
///
/// 1. Fetches the order detail to obtain the rider_trip_id.
/// 2. Seeds with the latest known rider location from the database.
/// 3. Subscribes to Supabase realtime inserts on `rider_location_log`.
/// 4. Emits [RiderLocation] values as they arrive.
final riderLocationStreamProvider =
    StreamProvider.autoDispose.family<RiderLocation, String>(
  (ref, orderId) {
    final controller = StreamController<RiderLocation>();
    final repo = ref.read(orderRepositoryProvider);

    // Track the channel so we can clean it up synchronously.
    RealtimeChannel? channel;

    // Register cleanup synchronously (before any async gap) so it
    // always runs even if the provider is disposed immediately.
    ref.onDispose(() {
      if (channel != null) {
        repo.removeChannel(channel!);
      }
      controller.close();
    });

    // Fire-and-forget async initialisation.
    () async {
      // 1. Fetch order to get trip ID.
      final detailAsync = await ref.read(orderDetailProvider(orderId).future);
      final order = detailAsync.order;
      final tripId = order['rider_trip_id'] as String?;

      if (tripId == null) {
        if (!controller.isClosed) {
          controller.addError(
            StateError('Order has no assigned rider trip'),
          );
        }
        return;
      }

      // 2. Seed with latest known location.
      try {
        final latest = await repo.getLatestRiderLocation(tripId);
        if (latest != null) {
          final loc = _parseLocationRecord(latest);
          if (loc != null && !controller.isClosed) {
            controller.add(loc);
          }
        }
      } catch (_) {
        // Best effort -- realtime updates will still work.
      }

      // 3. Subscribe to realtime inserts.
      if (controller.isClosed) return; // Already disposed.
      channel = repo.subscribeToRiderLocation(
        tripId,
        orderId,
        onInsert: (row) {
          final loc = _parseLocationRecord(row);
          if (loc != null && !controller.isClosed) {
            controller.add(loc);
          }
        },
      );
    }();

    return controller.stream;
  },
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse a `rider_location_log` row into a [RiderLocation].
///
/// The `location` column is stored as PostGIS WKT `POINT(lng lat)` or as a
/// GeoJSON-like map with `coordinates: [lng, lat]`.
RiderLocation? _parseLocationRecord(Map<String, dynamic> row) {
  final point = _tryParsePoint(row['location']);
  if (point == null) return null;

  final recordedAt = DateTime.tryParse(
        (row['recorded_at'] as String?) ?? '',
      ) ??
      DateTime.now();

  final speed = (row['speed_kmh'] as num?)?.toDouble();

  return RiderLocation(
    lat: point.$1,
    lng: point.$2,
    speedKmh: speed,
    recordedAt: recordedAt,
  );
}

/// Attempt to extract (lat, lng) from a PostGIS WKT or GeoJSON-like value.
(double lat, double lng)? _tryParsePoint(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    // PostGIS WKT: POINT(lng lat)
    final pointMatch = RegExp(
      r'^POINT\(([-\d.]+)\s+([-\d.]+)\)$',
    ).firstMatch(trimmed);
    if (pointMatch != null) {
      final lng = double.tryParse(pointMatch.group(1)!);
      final lat = double.tryParse(pointMatch.group(2)!);
      if (lat != null && lng != null) return (lat, lng);
    }

    // GeoJSON-like: {"type":"Point","coordinates":[lng,lat]}
    if (trimmed.startsWith('{') && trimmed.contains('coordinates')) {
      final coordsMatch = RegExp(
        r'"coordinates"\s*:\s*\[\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\]',
      ).firstMatch(trimmed);
      if (coordsMatch != null) {
        final lng = double.tryParse(coordsMatch.group(1)!);
        final lat = double.tryParse(coordsMatch.group(2)!);
        if (lat != null && lng != null) return (lat, lng);
      }
    }
  }

  if (value is Map<String, dynamic>) {
    final lat = (value['lat'] as num?)?.toDouble();
    final lng = (value['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) return (lat, lng);
  }

  return null;
}
