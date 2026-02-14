import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/theme.dart';
import '../services/location_tracking_service.dart';

/// Screen shown to riders during an active trip.
/// Displays the route map with the rider's live position and
/// controls to manage the trip lifecycle.
class TripTrackingScreen extends StatefulWidget {
  final String tripId;
  final LatLng origin;
  final LatLng destination;
  final String originName;
  final String destinationName;
  final List<LatLng>? routeCoordinates;
  final String initialStatus; // 'scheduled', 'in_transit'

  const TripTrackingScreen({
    super.key,
    required this.tripId,
    required this.origin,
    required this.destination,
    required this.originName,
    required this.destinationName,
    this.routeCoordinates,
    required this.initialStatus,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with WidgetsBindingObserver {
  final LocationTrackingService _tracker = LocationTrackingService();
  final MapController _mapController = MapController();

  late String _tripStatus;
  LatLng? _currentPosition;
  bool _actionLoading = false;
  String? _error;
  int _broadcastCount = 0;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tripStatus = widget.initialStatus;

    _tracker.onLocationBroadcast = (Position pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _broadcastCount++;
      });
    };

    _tracker.onError = (String err) {
      if (!mounted) return;
      setState(() => _error = err);
    };

    // If trip is already in_transit, start tracking immediately
    if (_tripStatus == 'in_transit') {
      _startTracking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Battery optimization: reduce frequency when backgrounded
    _tracker.setBackgrounded(
      state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive,
    );
  }

  Future<void> _startTracking() async {
    try {
      await _tracker.start(tripId: widget.tripId);
      setState(() => _error = null);
    } on LocationServiceException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _startTrip() async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });

    try {
      await _supabase
          .from('rider_trips')
          .update({'status': 'in_transit'})
          .eq('id', widget.tripId);

      setState(() {
        _tripStatus = 'in_transit';
        _actionLoading = false;
      });

      await _startTracking();
    } catch (e) {
      setState(() {
        _actionLoading = false;
        _error = 'Failed to start trip: $e';
      });
    }
  }

  Future<void> _completeTrip() async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });

    try {
      await _supabase
          .from('rider_trips')
          .update({'status': 'completed'})
          .eq('id', widget.tripId);

      // Only stop tracking after server confirms success
      _tracker.stop();

      if (!mounted) return;

      setState(() {
        _tripStatus = 'completed';
        _actionLoading = false;
      });

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _actionLoading = false;
        _error = 'Failed to complete trip: $e';
      });
    }
  }

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
          'This will stop tracking and cancel the trip. Orders may need to be reassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Trip',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _actionLoading = true;
      _error = null;
    });

    try {
      await _supabase
          .from('rider_trips')
          .update({'status': 'cancelled'})
          .eq('id', widget.tripId);

      // Only stop tracking after server confirms success
      _tracker.stop();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _actionLoading = false;
        _error = 'Failed to cancel trip: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds =
        LatLngBounds.fromPoints([widget.origin, widget.destination]);
    final isActive = _tripStatus == 'in_transit';

    return Scaffold(
      appBar: AppBar(
        title: Text(isActive ? 'Trip In Progress' : 'Trip'),
        actions: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(48),
                    ),
                    minZoom: mapMinZoom,
                    maxZoom: mapMaxZoom,
                    cameraConstraint: CameraConstraint.contain(
                      bounds:
                          LatLngBounds(nepalSouthWest, nepalNorthEast),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapTileUrl,
                      userAgentPackageName: 'com.jirisewa.mobile',
                    ),
                    // Route polyline
                    if (widget.routeCoordinates != null &&
                        widget.routeCoordinates!.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.routeCoordinates!,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.accent,
                            strokeWidth: isActive ? 5 : 4,
                            pattern: isActive
                                ? const StrokePattern.solid()
                                : StrokePattern.dashed(
                                    segments: const [10, 10],
                                  ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Origin marker
                        Marker(
                          point: widget.origin,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.trip_origin,
                            color: AppColors.secondary,
                            size: 32,
                          ),
                        ),
                        // Destination marker
                        Marker(
                          point: widget.destination,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: AppColors.error,
                            size: 40,
                          ),
                        ),
                        // Rider position
                        if (_currentPosition != null)
                          Marker(
                            point: _currentPosition!,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
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
                      attributions: [
                        TextSourceAttribution(mapAttribution),
                      ],
                    ),
                  ],
                ),
                // Broadcast count indicator
                if (isActive)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '$_broadcastCount updates sent',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Error bar
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFFEE2E2),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),

          // Info + action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Route info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.originName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                  color: Color(0xFF9CA3AF),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.destinationName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  if (_tripStatus == 'scheduled')
                    ElevatedButton(
                      onPressed: _actionLoading ? null : _startTrip,
                      child: Text(
                        _actionLoading ? 'Starting...' : 'Start Trip',
                      ),
                    ),

                  if (_tripStatus == 'in_transit') ...[
                    ElevatedButton(
                      onPressed: _actionLoading ? null : _completeTrip,
                      child: Text(
                        _actionLoading
                            ? 'Completing...'
                            : 'Complete Trip',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _actionLoading ? null : _cancelTrip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                      child: const Text('Cancel Trip'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
