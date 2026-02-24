import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/trips/providers/trip_detail_provider.dart';
import 'package:jirisewa_mobile/features/trips/providers/trips_provider.dart';
import 'package:jirisewa_mobile/features/trips/repositories/trip_repository.dart';

/// Route planning screen with OSRM-optimized stop ordering.
///
/// Shows all stops on a map with sequence numbers, a route summary bar,
/// a [ReorderableListView] for drag-to-reorder, and an "Optimize Route"
/// button that calls [TripRepository.recalculateTripRoute].
class RoutePlanScreen extends ConsumerStatefulWidget {
  final String tripId;

  const RoutePlanScreen({super.key, required this.tripId});

  @override
  ConsumerState<RoutePlanScreen> createState() => _RoutePlanScreenState();
}

class _RoutePlanScreenState extends ConsumerState<RoutePlanScreen> {
  /// Local copy of stops for instant reorder feedback.
  List<Map<String, dynamic>>? _localStops;

  bool _optimizing = false;
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (detailAsync.hasValue)
              Text(
                '${detailAsync.value!.trip['origin_name'] ?? '?'}'
                ' \u2192 '
                '${detailAsync.value!.trip['destination_name'] ?? '?'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load trip: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _localStops = null;
                  ref.invalidate(tripDetailProvider(widget.tripId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          // Sync local stops from provider if not locally modified.
          _localStops ??= List<Map<String, dynamic>>.from(
            data.stops.map((s) => Map<String, dynamic>.from(s)),
          );
          return _buildContent(data);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main content
  // ---------------------------------------------------------------------------

  Widget _buildContent(TripDetailData data) {
    final trip = data.trip;
    final stops = _localStops!;
    final origin = TripRepository.parsePoint(trip['origin']);
    final destination = TripRepository.parsePoint(trip['destination']);

    return Column(
      children: [
        // Map section
        SizedBox(
          height: 300,
          child: _buildMap(trip, stops, origin, destination),
        ),

        // Route summary bar
        _buildSummaryBar(trip, stops),

        // Stop list
        Expanded(
          child: stops.isEmpty
              ? Center(
                  child: Text(
                    'No stops on this trip yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : _buildReorderableStopList(stops),
        ),

        // Action bar
        _buildActionBar(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Map with numbered markers
  // ---------------------------------------------------------------------------

  Widget _buildMap(
    Map<String, dynamic> trip,
    List<Map<String, dynamic>> stops,
    LatLng? origin,
    LatLng? destination,
  ) {
    // Collect all points for bounds fitting.
    final allPoints = <LatLng>[];
    if (origin != null) allPoints.add(origin);
    if (destination != null) allPoints.add(destination);
    for (final stop in stops) {
      final point = TripRepository.parsePoint(stop['location']);
      if (point != null) allPoints.add(point);
    }

    if (allPoints.isEmpty) {
      allPoints.add(jiriCenter);
    }

    final bounds = allPoints.length >= 2
        ? LatLngBounds.fromPoints(allPoints)
        : LatLngBounds.fromPoints([allPoints.first, allPoints.first]);

    // Parse route polyline from trip data if available.
    final routePoints = _parseRouteFromTrip(trip);

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

        // Route polyline
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: AppColors.primary.withAlpha(180),
                strokeWidth: 4,
              ),
            ],
          ),

        // Stop markers with sequence numbers
        MarkerLayer(
          markers: [
            // Origin marker
            if (origin != null)
              Marker(
                point: origin,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.trip_origin,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

            // Numbered stop markers
            for (var i = 0; i < stops.length; i++)
              if (TripRepository.parsePoint(stops[i]['location']) != null)
                Marker(
                  point: TripRepository.parsePoint(stops[i]['location'])!,
                  width: 32,
                  height: 32,
                  child: _buildNumberedMarker(
                    index: i + 1,
                    type: stops[i]['type'] as String? ?? 'pickup',
                    isCompleted: stops[i]['completed'] == true,
                  ),
                ),

            // Destination marker
            if (destination != null)
              Marker(
                point: destination,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag,
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
    );
  }

  Widget _buildNumberedMarker({
    required int index,
    required String type,
    required bool isCompleted,
  }) {
    final isPickup = type == 'pickup';
    final Color bgColor;
    if (isCompleted) {
      bgColor = AppColors.secondary;
    } else if (isPickup) {
      bgColor = const Color(0xFF16A34A); // green-600
    } else {
      bgColor = AppColors.primary; // blue
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Route summary bar
  // ---------------------------------------------------------------------------

  Widget _buildSummaryBar(
    Map<String, dynamic> trip,
    List<Map<String, dynamic>> stops,
  ) {
    final distanceKm =
        (trip['total_distance_km'] as num?)?.toDouble();
    final durationMin =
        (trip['estimated_duration_minutes'] as num?)?.toInt();
    final completedCount = stops.where((s) => s['completed'] == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.muted,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Distance
          _summaryItem(
            icon: Icons.straighten,
            value: distanceKm != null
                ? '${distanceKm.toStringAsFixed(1)} km'
                : '--',
            label: 'Distance',
          ),
          const SizedBox(width: 24),

          // Duration
          _summaryItem(
            icon: Icons.schedule,
            value: durationMin != null ? _formatDuration(durationMin) : '--',
            label: 'Duration',
          ),
          const SizedBox(width: 24),

          // Stops
          _summaryItem(
            icon: Icons.pin_drop,
            value: '${stops.length}',
            label: '$completedCount done',
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reorderable stop list
  // ---------------------------------------------------------------------------

  Widget _buildReorderableStopList(List<Map<String, dynamic>> stops) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: stops.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final stop = stops[index];
        return _buildStopListItem(
          key: ValueKey(stop['id'] as String? ?? 'stop_$index'),
          stop: stop,
          index: index,
        );
      },
    );
  }

  Widget _buildStopListItem({
    required Key key,
    required Map<String, dynamic> stop,
    required int index,
  }) {
    final type = stop['type'] as String? ?? 'pickup';
    final isPickup = type == 'pickup';
    final isCompleted = stop['completed'] == true;
    final estimatedArrival = stop['estimated_arrival'] as String?;
    final locationName = stop['address'] as String? ??
        stop['location_name'] as String? ??
        '${_formatStopType(type)} #${index + 1}';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.secondary.withAlpha(15)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted
              ? AppColors.secondary.withAlpha(60)
              : AppColors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 12),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ),
            // Sequence number badge
            _buildSequenceBadge(index + 1, isPickup, isCompleted),
          ],
        ),
        title: Row(
          children: [
            Icon(
              isPickup ? Icons.agriculture : Icons.local_shipping,
              size: 18,
              color: isPickup
                  ? const Color(0xFF16A34A)
                  : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                locationName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration:
                      isCompleted ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: estimatedArrival != null
            ? Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'ETA: ${_formatTime(estimatedArrival)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )
            : null,
        trailing: isCompleted
            ? const Icon(
                Icons.check_circle,
                color: AppColors.secondary,
                size: 22,
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPickup
                      ? const Color(0xFF16A34A).withAlpha(25)
                      : AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatStopType(type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPickup
                        ? const Color(0xFF16A34A)
                        : AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSequenceBadge(int number, bool isPickup, bool isCompleted) {
    final Color bgColor;
    if (isCompleted) {
      bgColor = AppColors.secondary;
    } else if (isPickup) {
      bgColor = const Color(0xFF16A34A);
    } else {
      bgColor = AppColors.primary;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action bar
  // ---------------------------------------------------------------------------

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_optimizing || _reordering) ? null : _optimizeRoute,
            icon: _optimizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.route),
            label: Text(
              _optimizing ? 'Optimizing...' : 'Optimize Route',
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_reordering || _localStops == null) return;

    // Adjust for ReorderableListView behavior.
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    setState(() {
      _reordering = true;
      final item = _localStops!.removeAt(oldIndex);
      _localStops!.insert(newIndex, item);
    });

    try {
      final stopIds = _localStops!
          .map((s) => s['id'] as String)
          .toList();
      final repo = ref.read(tripRepositoryProvider);
      await repo.reorderStops(widget.tripId, stopIds);
      if (!mounted) return;
      // Refresh provider data to sync.
      _localStops = null;
      ref.invalidate(tripDetailProvider(widget.tripId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reorder failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      // Revert by refreshing from server.
      _localStops = null;
      ref.invalidate(tripDetailProvider(widget.tripId));
    } finally {
      if (mounted) {
        setState(() => _reordering = false);
      }
    }
  }

  Future<void> _optimizeRoute() async {
    setState(() => _optimizing = true);
    try {
      final repo = ref.read(tripRepositoryProvider);
      final success = await repo.recalculateTripRoute(widget.tripId);
      if (!mounted) return;
      if (success) {
        // Clear local stops so they reload from server with new ordering.
        _localStops = null;
        ref.invalidate(tripDetailProvider(widget.tripId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimized successfully'),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimization failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Optimization error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _optimizing = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Route parsing
  // ---------------------------------------------------------------------------

  /// Parse route polyline from trip's `route` field (WKT LINESTRING or GeoJSON).
  List<LatLng> _parseRouteFromTrip(Map<String, dynamic> trip) {
    final routeValue = trip['route'];
    if (routeValue == null) return [];

    if (routeValue is String) {
      final trimmed = routeValue.trim();

      // WKT LINESTRING
      final linestringMatch = RegExp(
        r'^LINESTRING\((.+)\)$',
      ).firstMatch(trimmed);
      if (linestringMatch != null) {
        final coordStr = linestringMatch.group(1)!;
        final points = <LatLng>[];
        for (final pair in coordStr.split(',')) {
          final parts = pair.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final lng = double.tryParse(parts[0]);
            final lat = double.tryParse(parts[1]);
            if (lng != null && lat != null) {
              points.add(LatLng(lat, lng));
            }
          }
        }
        return points;
      }

      // Try GeoJSON string
      if (trimmed.startsWith('{')) {
        try {
          final decoded = json.decode(trimmed) as Map<String, dynamic>;
          return _parseGeoJsonCoords(decoded);
        } catch (_) {
          return [];
        }
      }
    }

    if (routeValue is Map<String, dynamic>) {
      return _parseGeoJsonCoords(routeValue);
    }

    return [];
  }

  List<LatLng> _parseGeoJsonCoords(Map<String, dynamic> geoJson) {
    final coords = geoJson['coordinates'] as List<dynamic>?;
    if (coords == null) return [];
    return coords
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2)
        .map((pair) => LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatStopType(String type) {
    switch (type) {
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  String _formatTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}
