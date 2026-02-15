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
  final LatLng? currentPosition;
  final bool isActive;

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
    this.currentPosition,
    this.isActive = false,
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
        oldWidget.destination != widget.destination ||
        oldWidget.routeCoordinates != widget.routeCoordinates) {
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
                    color: widget.isActive
                        ? const Color(0xFF059669)
                        : const Color(0xFF3B82F6),
                    strokeWidth: widget.isActive ? 5 : 4,
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
                if (widget.currentPosition != null)
                  Marker(
                    point: widget.currentPosition!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.two_wheeler,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [TextSourceAttribution(mapAttribution)],
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
