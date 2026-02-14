import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/models/rider_trip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../map/widgets/route_map.dart';
import '../../orders/screens/order_detail_screen.dart';
import 'active_trip_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _supabase = Supabase.instance.client;

  RiderTrip? _trip;
  List<models.Order> _matchedOrders = [];
  bool _loading = true;
  double? _distanceKm;
  String? _durationLabel;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('rider_trips')
          .select('*, rider:users!rider_id(name, phone, rating_avg)')
          .eq('id', widget.tripId)
          .single();

      final trip = RiderTrip.fromJson(data);

      // Load matched orders for this trip
      final ordersData = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
          .eq('rider_trip_id', widget.tripId)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        _trip = trip;
        _matchedOrders = (ordersData as List)
            .map((j) => models.Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Failed to load trip: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_trip != null
            ? '${_trip!.originName.split(',').first} → ${_trip!.destinationName.split(',').first}'
            : 'Trip'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trip == null
              ? const Center(child: Text('Trip not found'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final trip = _trip!;
    final auth = context.read<AuthProvider>();
    final isOwner = auth.userId == trip.riderId;
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        // Route map
        SizedBox(
          height: 250,
          child: RouteMapWidget(
            origin: trip.origin,
            destination: trip.destination,
            originName: trip.originName,
            destinationName: trip.destinationName,
            onRouteLoaded: (distanceM, durationS) {
              if (!mounted) return;
              setState(() {
                _distanceKm = distanceM / 1000;
                final hours = (durationS / 3600).floor();
                final mins = ((durationS % 3600) / 60).floor();
                _durationLabel = hours > 0
                    ? '${hours}h ${mins}m'
                    : '${mins}m';
              });
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Route info chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(Icons.schedule,
                      dateFormat.format(trip.departureAt.toLocal())),
                  _infoChip(Icons.fitness_center,
                      '${trip.remainingCapacityKg.toStringAsFixed(0)}/${trip.availableCapacityKg.toStringAsFixed(0)} kg'),
                  if (_distanceKm != null)
                    _infoChip(Icons.straighten,
                        '${_distanceKm!.toStringAsFixed(1)} km'),
                  if (_durationLabel != null)
                    _infoChip(Icons.timer, _durationLabel!),
                  _statusChip(trip.status),
                ],
              ),
              const SizedBox(height: 16),

              // Origin / destination
              _routeRow(
                Icons.trip_origin,
                AppColors.secondary,
                'From',
                trip.originName,
              ),
              const SizedBox(height: 8),
              _routeRow(
                Icons.location_pin,
                AppColors.error,
                'To',
                trip.destinationName,
              ),

              const SizedBox(height: 24),

              // Matched orders
              Text('Matched Orders (${_matchedOrders.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              if (_matchedOrders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No orders matched to this trip yet.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ..._matchedOrders.map((order) => Card(
                      child: ListTile(
                        leading: Icon(
                          order.status.isActive
                              ? Icons.local_shipping
                              : Icons.check_circle,
                          color: order.status.isActive
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                        title: Text(
                          order.items
                              .map((i) => i.listingName('en'))
                              .join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                            '${order.status.label} — NPR ${order.grandTotal.toStringAsFixed(0)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(orderId: order.id),
                          ));
                        },
                      ),
                    )),

              const SizedBox(height: 24),

              // Actions
              if (isOwner && trip.status == TripStatus.scheduled) ...[
                ElevatedButton.icon(
                  onPressed: () => _startTrip(trip),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Trip'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _cancelTrip(trip),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Cancel Trip'),
                ),
              ],

              if (isOwner && trip.status == TripStatus.inTransit) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ActiveTripScreen(tripId: trip.id),
                    ));
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Continue Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _statusChip(TripStatus status) {
    Color color;
    switch (status) {
      case TripStatus.scheduled:
        color = AppColors.primary;
      case TripStatus.inTransit:
        color = AppColors.secondary;
      case TripStatus.completed:
        color = const Color(0xFF059669);
      case TripStatus.cancelled:
        color = AppColors.error;
    }

    return Chip(
      label: Text(status.label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      backgroundColor: color.withAlpha(20),
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _routeRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Future<void> _startTrip(RiderTrip trip) async {
    try {
      await _supabase
          .from('rider_trips')
          .update({'status': TripStatus.inTransit.dbValue})
          .eq('id', trip.id);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ActiveTripScreen(tripId: trip.id),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start trip: $e')),
      );
    }
  }

  Future<void> _cancelTrip(RiderTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
            'This will cancel the trip and unlink any matched orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Trip',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('rider_trips')
          .update({'status': TripStatus.cancelled.dbValue})
          .eq('id', trip.id);
      _loadTrip();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  }
}
