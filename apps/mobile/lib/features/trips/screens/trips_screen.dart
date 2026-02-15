import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';

/// Trips screen — rider views upcoming, active, and past trips.
/// Full implementation will be in ts-wbdx.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final session = SessionProvider.of(context);
    final currentProfile = session.profile;
    if (!session.isAuthenticated || currentProfile == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _supabase
          .from('rider_trips')
          .select(
            'id, origin_name, destination_name, departure_at, status, remaining_capacity_kg, available_capacity_kg',
          )
          .eq('rider_id', currentProfile.id)
          .order('departure_at', ascending: false)
          .limit(20);

      setState(() {
        _trips = List<Map<String, dynamic>>.from(result);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load trips: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'My Trips',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadTrips,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No trips yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Post a trip to start delivering',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: ListView.builder(
                        itemCount: _trips.length,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemBuilder: (ctx, i) => _tripTile(_trips[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripTile(Map<String, dynamic> trip) {
    final status = trip['status'] as String? ?? 'scheduled';
    final remaining = (trip['remaining_capacity_kg'] as num?)?.toDouble() ?? 0;
    final total = (trip['available_capacity_kg'] as num?)?.toDouble() ?? 0;
    final origin = _coordinatesForPlace(trip['origin_name'] as String?);
    final destination = _coordinatesForPlace(
      trip['destination_name'] as String?,
    );

    return Card(
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
                        '${trip['origin_name'] ?? '?'} → ${trip['destination_name'] ?? '?'}',
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
              ],
            ),
          ],
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

  LatLng _coordinatesForPlace(String? placeName) {
    switch ((placeName ?? '').trim().toLowerCase()) {
      case 'jiri':
        return const LatLng(27.6306, 86.2305);
      case 'charikot':
        return const LatLng(27.6681, 86.0290);
      case 'banepa':
        return const LatLng(27.6298, 85.5215);
      case 'kathmandu':
        return const LatLng(27.7172, 85.3240);
      default:
        return jiriCenter;
    }
  }
}
