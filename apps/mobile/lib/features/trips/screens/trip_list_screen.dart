import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/rider_trip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import 'post_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  List<RiderTrip> _activeTrips = [];
  List<RiderTrip> _pastTrips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('rider_trips')
          .select('*, rider:users!rider_id(name, phone, rating_avg)')
          .eq('rider_id', userId)
          .order('departure_at', ascending: false);

      if (!mounted) return;

      final trips = (data as List)
          .map((j) => RiderTrip.fromJson(j as Map<String, dynamic>))
          .toList();

      setState(() {
        _activeTrips = trips.where((t) => t.status.isActive).toList();
        _pastTrips = trips.where((t) => !t.status.isActive).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Failed to load trips: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active (${_activeTrips.length})'),
            Tab(text: 'Past (${_pastTrips.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PostTripScreen()),
          );
          _loadTrips();
        },
        icon: const Icon(Icons.add),
        label: const Text('Post Trip'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList(_activeTrips, empty: 'No active trips'),
                  _buildTripList(_pastTrips, empty: 'No past trips'),
                ],
              ),
      ),
    );
  }

  Widget _buildTripList(List<RiderTrip> trips, {required String empty}) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(empty, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildTripCard(trips[index]),
    );
  }

  Widget _buildTripCard(RiderTrip trip) {
    final dateFormat = DateFormat('MMM d, h:mm a');

    Color statusColor;
    switch (trip.status) {
      case TripStatus.scheduled:
        statusColor = AppColors.primary;
      case TripStatus.inTransit:
        statusColor = AppColors.secondary;
      case TripStatus.completed:
        statusColor = const Color(0xFF059669);
      case TripStatus.cancelled:
        statusColor = AppColors.error;
    }

    return Card(
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TripDetailScreen(tripId: trip.id),
          ));
          _loadTrips();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${trip.originName} → ${trip.destinationName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trip.status.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(trip.departureAt.toLocal()),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.fitness_center, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.remainingCapacityKg.toStringAsFixed(0)}/${trip.availableCapacityKg.toStringAsFixed(0)} kg',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
