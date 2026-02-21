import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/orders/providers/orders_provider.dart';
import 'package:jirisewa_mobile/features/orders/providers/tracking_provider.dart';

/// Full-screen map view for tracking a rider's live position during delivery.
///
/// Shows the route polyline, pickup marker(s), delivery marker, and a live
/// rider marker that updates in real-time via Supabase realtime subscription.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _staleTimer;
  DateTime? _lastUpdateAt;

  /// Whether the camera should auto-follow the rider position.
  bool _autoFollow = true;

  @override
  void dispose() {
    _staleTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final riderLocAsync = ref.watch(riderLocationStreamProvider(widget.orderId));

    // Start a periodic timer to refresh the stale indicator.
    _staleTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    return Scaffold(
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load order: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(orderDetailProvider(widget.orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final order = data.order;
          final items = data.items;
          final delivery = _deliveryPoint(order);
          final pickups = _pickupPoints(items);
          final status = order['status'] as String? ?? 'pending';
          final isTracking =
              status == 'picked_up' || status == 'in_transit';

          // Determine rider position from the stream.
          RiderLocation? riderLoc;
          if (riderLocAsync.hasValue) {
            riderLoc = riderLocAsync.value;
          }

          if (riderLoc != null) {
            _lastUpdateAt = riderLoc.recordedAt;
          }

          final riderLatLng = riderLoc != null
              ? LatLng(riderLoc.lat, riderLoc.lng)
              : null;

          // Auto-follow: move camera to rider when a new location arrives.
          if (_autoFollow && riderLatLng != null) {
            // Schedule after build to avoid setState-during-build issues.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _mapController.move(riderLatLng, _mapController.camera.zoom);
              }
            });
          }

          final isStale = _lastUpdateAt != null &&
              DateTime.now().difference(_lastUpdateAt!).inSeconds > 30;

          // Points for initial camera fit.
          final allPoints = <LatLng>[delivery, ...pickups];
          if (riderLatLng != null) allPoints.add(riderLatLng);

          return Stack(
            children: [
              // -- Full-screen map --
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(
                      allPoints.length > 1
                          ? allPoints
                          : [delivery, delivery],
                    ),
                    padding: const EdgeInsets.all(64),
                  ),
                  minZoom: mapMinZoom,
                  maxZoom: mapMaxZoom,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(nepalSouthWest, nepalNorthEast),
                  ),
                  onMapEvent: (event) {
                    // Disable auto-follow when the user drags the map.
                    if (event is MapEventMoveStart &&
                        event.source == MapEventSource.dragStart) {
                      _autoFollow = false;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl,
                    userAgentPackageName: 'com.jirisewa.mobile',
                  ),

                  // Route polyline (straight lines between pickup -> delivery
                  // when no OSRM route is available; good enough for tracking view).
                  if (pickups.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [...pickups, delivery],
                          color: isTracking
                              ? const Color(0xFF059669)
                              : const Color(0xFF3B82F6),
                          strokeWidth: isTracking ? 5 : 4,
                          pattern: isTracking
                              ? const StrokePattern.solid()
                              : StrokePattern.dashed(segments: [8, 8]),
                        ),
                      ],
                    ),

                  // Markers: pickups, delivery, rider.
                  MarkerLayer(
                    markers: [
                      // Pickup markers (green).
                      for (final pickup in pickups)
                        Marker(
                          point: pickup,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.trip_origin,
                            color: Color(0xFF10B981),
                            size: 32,
                          ),
                        ),

                      // Delivery marker (red).
                      Marker(
                        point: delivery,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFEF4444),
                          size: 40,
                        ),
                      ),

                      // Live rider marker (blue circle with motorcycle icon).
                      if (riderLatLng != null)
                        Marker(
                          point: riderLatLng,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
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
                              size: 20,
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

              // -- Back button overlay --
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: SafeArea(
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),

              // -- Re-center FAB (visible when auto-follow is off) --
              if (!_autoFollow && riderLatLng != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.my_location,
                            color: AppColors.primary),
                        onPressed: () {
                          setState(() => _autoFollow = true);
                          _mapController.move(
                            riderLatLng,
                            _mapController.camera.zoom.clamp(14.0, 17.0),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // -- Bottom info card --
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: _buildInfoCard(
                  status: status,
                  riderLoc: riderLoc,
                  isStale: isStale,
                  isTracking: isTracking,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom info card
  // ---------------------------------------------------------------------------

  Widget _buildInfoCard({
    required String status,
    required RiderLocation? riderLoc,
    required bool isStale,
    required bool isTracking,
  }) {
    final statusLabel = _formatStatus(status);
    final speedLabel = riderLoc?.speedKmh != null
        ? '${riderLoc!.speedKmh!.toStringAsFixed(1)} km/h'
        : null;
    final updatedLabel = _lastUpdateAt != null
        ? _formatTimeAgo(_lastUpdateAt!)
        : null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row.
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(status),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isStale && isTracking)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, size: 14, color: Colors.amber[800]),
                        const SizedBox(width: 4),
                        Text(
                          'Signal stale',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (isTracking) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (speedLabel != null) ...[
                    const Icon(Icons.speed, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      speedLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (updatedLabel != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isStale ? Colors.amber[800] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      updatedLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: isStale ? Colors.amber[800] : Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],

            if (!isTracking && riderLoc == null) ...[
              const SizedBox(height: 8),
              Text(
                'Waiting for rider GPS signal...',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Location parsing helpers
  // ---------------------------------------------------------------------------

  /// Extract the delivery point from an order row.
  LatLng _deliveryPoint(Map<String, dynamic> order) {
    final parsed = _tryParsePoint(order['delivery_location']);
    if (parsed != null) return parsed;
    return _addressFallback(order['delivery_address'] as String?);
  }

  /// Extract unique pickup points from order items.
  List<LatLng> _pickupPoints(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final points = <LatLng>[];

    for (final item in items) {
      final raw = item['pickup_location'];
      final key = raw?.toString() ?? '';
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);

      final point = _tryParsePoint(raw);
      if (point != null) points.add(point);
    }

    // Fallback: use Jiri if no pickup locations found.
    if (points.isEmpty) {
      points.add(jiriCenter);
    }
    return points;
  }

  /// Attempt to parse a PostGIS WKT, GeoJSON-like, or map value into LatLng.
  LatLng? _tryParsePoint(dynamic value) {
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
        if (lat != null && lng != null) return LatLng(lat, lng);
      }

      // GeoJSON-like: {"type":"Point","coordinates":[lng,lat]}
      if (trimmed.startsWith('{') && trimmed.contains('coordinates')) {
        final coordsMatch = RegExp(
          r'"coordinates"\s*:\s*\[\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\]',
        ).firstMatch(trimmed);
        if (coordsMatch != null) {
          final lng = double.tryParse(coordsMatch.group(1)!);
          final lat = double.tryParse(coordsMatch.group(2)!);
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    }

    if (value is Map<String, dynamic>) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    return null;
  }

  /// Simple address-based fallback when no geo coordinates are available.
  LatLng _addressFallback(String? address) {
    final lower = (address ?? '').toLowerCase();
    if (lower.contains('kathmandu')) return const LatLng(27.7172, 85.3240);
    if (lower.contains('banepa')) return const LatLng(27.6298, 85.5215);
    if (lower.contains('charikot')) return const LatLng(27.6681, 86.0290);
    if (lower.contains('jiri')) return const LatLng(27.6306, 86.2305);
    return jiriCenter;
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.secondary;
      case 'cancelled':
      case 'disputed':
        return AppColors.error;
      case 'in_transit':
      case 'picked_up':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }
}
