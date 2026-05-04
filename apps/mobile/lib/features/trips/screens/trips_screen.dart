import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/ping_beacon_map.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';
import 'package:jirisewa_mobile/features/tracking/screens/trip_tracking_screen.dart';
import 'package:jirisewa_mobile/features/trips/providers/trips_provider.dart';
import 'package:jirisewa_mobile/features/trips/repositories/trip_repository.dart';

/// Rider workflow screen:
/// - Trip route/capacity
/// - Connected orders for each trip
/// - Jump to live tracking for execution
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  Set<String> _respondingPingIds = {};
  RealtimeChannel? _pingChannel;
  String? _subscribedRiderId;

  /// Captured reference to the repository so we can clean up the channel in
  /// [dispose] without reading from [ref] (which is invalid after unmount).
  TripRepository? _tripRepo;

  @override
  void dispose() {
    _cleanupPingSubscription();
    super.dispose();
  }

  void _cleanupPingSubscription() {
    final channel = _pingChannel;
    _pingChannel = null;
    _subscribedRiderId = null;
    if (channel != null) {
      _tripRepo?.removeChannel(channel);
    }
  }

  void _maybeSubscribeToPings() {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;
    final riderId = profile.id;

    if (_subscribedRiderId == riderId && _pingChannel != null) return;

    _cleanupPingSubscription();
    _subscribedRiderId = riderId;
    _tripRepo = ref.read(tripRepositoryProvider);
    _pingChannel = _tripRepo!.subscribeToPings(
      riderId,
      onEvent: (_) {
        // A ping was inserted or updated; invalidate to refetch all data.
        ref.invalidate(tripsDataProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsDataAsync = ref.watch(tripsDataProvider);

    // Set up the ping subscription when data arrives.
    ref.listen(tripsDataProvider, (prev, next) {
      final data = next.valueOrNull;
      if (data != null) {
        _maybeSubscribeToPings();
      }
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.tripNew),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Rider Connection Flow',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Trips connect farmer pickups to customer deliveries.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            Expanded(
              child: tripsDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text('Failed to load trips: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(tripsDataProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (data) => _buildDataContent(data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataContent(TripsData data) {
    final trips = data.trips;
    final unassignedOrders = data.unassignedOrders;

    return Column(
      children: [
        if (unassignedOrders.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${unassignedOrders.length} orders are awaiting trip assignment.',
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No trips yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Post a trip to start connecting farmers and customers',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(tripsDataProvider.future),
                  child: ListView.builder(
                    itemCount: trips.length,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    itemBuilder: (ctx, i) => _tripTile(
                      trips[i],
                      data.ordersByTripId,
                      data.pingsByTripId,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tripTile(
    Map<String, dynamic> trip,
    Map<String, List<Map<String, dynamic>>> ordersByTripId,
    Map<String, List<Map<String, dynamic>>> pingsByTripId,
  ) {
    final tripId = trip['id'] as String? ?? '';
    final status = trip['status'] as String? ?? 'scheduled';
    final remaining = (trip['remaining_capacity_kg'] as num?)?.toDouble() ?? 0;
    final total = (trip['available_capacity_kg'] as num?)?.toDouble() ?? 0;
    final origin = _parsePointOrFallback(trip['origin']);
    final destination = _parsePointOrFallback(trip['destination']);
    final linkedOrders = ordersByTripId[tripId] ?? const [];
    final opportunities = pingsByTripId[tripId] ?? const [];

    return GestureDetector(
      onTap: () => context.push('/trips/$tripId'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: AppColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _tripStatusColor(status).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.route,
                      color: _tripStatusColor(status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip['origin_name'] ?? '?'} \u2192 ${trip['destination_name'] ?? '?'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 13,
                            color: _tripStatusColor(status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 160,
                  child: RouteMapWidget(
                    origin: origin,
                    destination: destination,
                    originName: trip['origin_name'] as String?,
                    destinationName: trip['destination_name'] as String?,
                    routeCoordinates: [origin, destination],
                    isActive: status == 'in_transit',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.fitness_center, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${remaining.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} kg available',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '${linkedOrders.length} linked orders',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (opportunities.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sensors,
                        size: 18,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${opportunities.length} farmer beacons on this route',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showBeaconSheet(
                          trip: trip,
                          opportunities: opportunities,
                        ),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ),
              ],
              if (linkedOrders.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...linkedOrders.take(2).map((order) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order['delivery_address'] as String? ??
                                'Delivery address',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatStatus(
                            order['status'] as String? ?? 'pending',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 10),
              if (status == 'scheduled' || status == 'in_transit')
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _openTripTracking(trip, linkedOrders),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: Text(
                      status == 'scheduled'
                          ? 'Start Trip Flow'
                          : 'Open Live Tracking',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBeaconSheet({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> opportunities,
  }) async {
    final origin = _parsePointOrFallback(trip['origin']);
    final destination = _parsePointOrFallback(trip['destination']);
    final totalEarnings = opportunities.fold<double>(
      0,
      (sum, row) =>
          sum + ((row['estimated_earnings'] as num?)?.toDouble() ?? 0),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Farmer Route Beacons',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${opportunities.length} opportunities \u00b7 potential NPR ${totalEarnings.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 260,
                      child: PingBeaconMap(
                        origin: origin,
                        destination: destination,
                        opportunities: opportunities,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: opportunities.length,
                      itemBuilder: (context, i) {
                        final opp = opportunities[i];
                        final pingId = opp['id'] as String? ?? '';
                        final isBusy = _respondingPingIds.contains(pingId);
                        final earning =
                            (opp['estimated_earnings'] as num?)?.toDouble() ??
                            0;
                        final detourKm =
                            ((opp['detour_distance_m'] as num?)?.toDouble() ??
                                0) /
                            1000;
                        final pickups = _pickupNames(opp['pickup_locations']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD1FAE5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.agriculture_outlined,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pickups.isEmpty
                                          ? 'Farmer pickup'
                                          : pickups.join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'NPR ${earning.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Detour ~${detourKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isBusy
                                          ? null
                                          : () => _declinePing(opp),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: isBusy
                                          ? null
                                          : () => _acceptPing(opp),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                      ),
                                      child: Text(
                                        isBusy ? 'Working...' : 'Accept',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _pickupNames(dynamic pickupLocations) {
    if (pickupLocations is! List) return const [];
    return pickupLocations
        .map(
          (p) => p is Map && p['farmerName'] is String
              ? p['farmerName'] as String
              : null,
        )
        .whereType<String>()
        .toList();
  }

  Future<void> _acceptPing(Map<String, dynamic> ping) async {
    final pingId = ping['id'] as String?;
    if (pingId == null) return;

    setState(() {
      _respondingPingIds = {..._respondingPingIds, pingId};
    });

    try {
      final repo = ref.read(tripRepositoryProvider);
      final row = await repo.acceptPing(pingId);
      final ok = row['success'] == true;
      final message =
          row['message'] as String? ?? (ok ? 'Ping accepted' : 'Failed');
      final tripId = row['trip_id'] as String? ?? ping['trip_id'] as String?;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? const Color(0xFF059669) : AppColors.error,
        ),
      );

      if (ok && tripId != null) {
        final routeUpdated = await repo.recalculateTripRoute(tripId);
        if (mounted && !routeUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order accepted. Route optimization skipped; using existing path.',
              ),
            ),
          );
        }
      }
      ref.invalidate(tripsDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept ping: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _respondingPingIds = {..._respondingPingIds}..remove(pingId);
        });
      }
    }
  }

  Future<void> _declinePing(Map<String, dynamic> ping) async {
    final pingId = ping['id'] as String?;
    if (pingId == null) return;

    setState(() {
      _respondingPingIds = {..._respondingPingIds, pingId};
    });

    try {
      final repo = ref.read(tripRepositoryProvider);
      final row = await repo.declinePing(pingId);
      final ok = row['success'] == true;
      final message =
          row['message'] as String? ?? (ok ? 'Ping declined' : 'Failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? AppColors.primary : AppColors.error,
        ),
      );
      ref.invalidate(tripsDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline ping: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _respondingPingIds = {..._respondingPingIds}..remove(pingId);
        });
      }
    }
  }

  void _openTripTracking(
    Map<String, dynamic> trip,
    List<Map<String, dynamic>> linkedOrders,
  ) {
    final origin = _parsePointOrFallback(trip['origin']);
    final destination = _parsePointOrFallback(trip['destination']);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripTrackingScreen(
          tripId: trip['id'] as String? ?? '',
          origin: origin,
          destination: destination,
          originName: trip['origin_name'] as String? ?? 'Origin',
          destinationName: trip['destination_name'] as String? ?? 'Destination',
          routeCoordinates: [origin, destination],
          initialStatus: trip['status'] as String? ?? 'scheduled',
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  Color _tripStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      case 'in_transit':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  /// Parse a PostGIS point from the trip row, falling back to [jiriCenter].
  LatLng _parsePointOrFallback(dynamic value) {
    return TripRepository.parsePoint(value) ?? jiriCenter;
  }
}
