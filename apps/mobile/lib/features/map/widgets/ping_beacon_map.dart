import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/map_constants.dart';

/// Beacon map for rider opportunities (farmer pickups + delivery drops).
class PingBeaconMap extends StatelessWidget {
  final LatLng origin;
  final LatLng destination;
  final List<Map<String, dynamic>> opportunities;

  const PingBeaconMap({
    super.key,
    required this.origin,
    required this.destination,
    required this.opportunities,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[origin, destination];

    for (final opp in opportunities) {
      final pickupLocations = _asList(opp['pickup_locations']);
      for (final p in pickupLocations) {
        final loc = _parseLatLng(p);
        if (loc != null) points.add(loc);
      }
      final delivery = _parseLatLng(opp['delivery_location']);
      if (delivery != null) points.add(delivery);
    }

    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
        ),
        minZoom: mapMinZoom,
        maxZoom: mapMaxZoom,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(nepalSouthWest, nepalNorthEast),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl,
          userAgentPackageName: 'com.jirisewa.mobile',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [origin, destination],
              color: const Color(0xFF3B82F6),
              strokeWidth: 3,
              pattern: StrokePattern.dashed(segments: [8, 8]),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: origin,
              width: 34,
              height: 34,
              child: const Icon(
                Icons.trip_origin,
                color: Color(0xFF2563EB),
                size: 28,
              ),
            ),
            Marker(
              point: destination,
              width: 36,
              height: 36,
              child: const Icon(
                Icons.location_pin,
                color: Color(0xFF1D4ED8),
                size: 32,
              ),
            ),
            ..._buildOpportunityMarkers(opportunities),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution(mapAttribution)],
        ),
      ],
    );
  }

  List<Marker> _buildOpportunityMarkers(List<Map<String, dynamic>> rows) {
    final markers = <Marker>[];

    for (final row in rows) {
      final pickupLocations = _asList(row['pickup_locations']);
      final earning = (row['estimated_earnings'] as num?)?.toDouble() ?? 0;
      final detourM = (row['detour_distance_m'] as num?)?.toDouble() ?? 0;

      for (final pickup in pickupLocations) {
        final loc = _parseLatLng(pickup);
        if (loc == null) continue;
        final farmerName = (pickup is Map && pickup['farmerName'] is String)
            ? pickup['farmerName'] as String
            : 'Farmer pickup';
        markers.add(
          Marker(
            point: loc,
            width: 34,
            height: 34,
            child: Tooltip(
              message:
                  '$farmerName\nEarning: NPR ${earning.toStringAsFixed(0)}\nDetour: ${(detourM / 1000).toStringAsFixed(1)} km',
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(55),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.agriculture_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        );
      }

      final delivery = _parseLatLng(row['delivery_location']);
      if (delivery != null) {
        markers.add(
          Marker(
            point: delivery,
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const [];
  }

  LatLng? _parseLatLng(dynamic value) {
    if (value is Map) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }
}
