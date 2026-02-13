import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/services/geocoding_service.dart';

/// Displays a trip route as a polyline between origin and destination.
/// Fetches the route from OSRM if [routeCoordinates] is not provided.
class RouteMapWidget extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String? originName;
  final String? destinationName;

  /// Pre-computed route coordinates. If null, fetches via OSRM.
  final List<LatLng>? routeCoordinates;

  /// Called when route is loaded with distance (meters) and duration (seconds).
  final void Function(double distanceMeters, double durationSeconds)?
      onRouteLoaded;

  const RouteMapWidget({
    super.key,
    required this.origin,
    required this.destination,
    this.originName,
    this.destinationName,
    this.routeCoordinates,
    this.onRouteLoaded,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final GeocodingService _geocodingService = GeocodingService();

  List<LatLng> _routePoints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _geocodingService.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin != widget.origin ||
        oldWidget.destination != widget.destination) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    if (widget.routeCoordinates != null) {
      setState(() {
        _routePoints = widget.routeCoordinates!;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    final result = await _geocodingService.fetchRoute(
      widget.origin,
      widget.destination,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _routePoints = result.coordinates;
        _loading = false;
      });
      widget.onRouteLoaded?.call(result.distanceMeters, result.durationSeconds);
    } else {
      // Fallback: straight line
      setState(() {
        _routePoints = [widget.origin, widget.destination];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints([widget.origin, widget.destination]);

    return Stack(
      children: [
        FlutterMap(
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
            if (!_loading && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF3B82F6),
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.origin,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.trip_origin,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
                Marker(
                  point: widget.destination,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Color(0xFFEF4444),
                    size: 40,
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(mapAttribution),
              ],
            ),
          ],
        ),
        if (_loading)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading route...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
