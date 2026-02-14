import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/models/produce_listing.dart';
import '../../../core/models/rider_trip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../marketplace/screens/produce_detail_screen.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../../trips/screens/trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  List<models.Order> _recentOrders = [];
  List<ProduceListing> _nearbyProduce = [];
  List<RiderTrip> _upcomingTrips = [];
  int _pendingFarmerOrders = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final roles = auth.roles;
      final futures = <Future>[];

      // Consumer/all: recent orders
      futures.add(
        _supabase
            .from('orders')
            .select('*, consumer:users!consumer_id(name), rider:users!rider_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
            .eq('consumer_id', userId)
            .order('created_at', ascending: false)
            .limit(3)
            .then((data) {
          _recentOrders = (data as List)
              .map((j) => models.Order.fromJson(j as Map<String, dynamic>))
              .toList();
        }),
      );

      // Consumer: nearby produce
      futures.add(
        _supabase
            .from('produce_listings')
            .select('*, farmer:users!farmer_id(name, phone, rating_avg), category:produce_categories(name_en, name_ne)')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(6)
            .then((data) {
          _nearbyProduce = (data as List)
              .map((j) => ProduceListing.fromJson(j as Map<String, dynamic>))
              .toList();
        }),
      );

      // Rider: upcoming trips
      if (roles.contains(UserRole.rider)) {
        futures.add(
          _supabase
              .from('rider_trips')
              .select('*, rider:users!rider_id(name, phone, rating_avg)')
              .eq('rider_id', userId)
              .inFilter('status', ['scheduled', 'in_transit'])
              .order('departure_at')
              .limit(3)
              .then((data) {
            _upcomingTrips = (data as List)
                .map((j) => RiderTrip.fromJson(j as Map<String, dynamic>))
                .toList();
          }),
        );
      }

      // Farmer: pending orders count
      if (roles.contains(UserRole.farmer)) {
        futures.add(
          _supabase
              .from('order_items')
              .select('id')
              .eq('farmer_id', userId)
              .eq('pickup_confirmed', false)
              .then((data) {
            _pendingFarmerOrders = (data as List).length;
          }),
        );
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.profile?.name ?? 'User';
    final roles = auth.roles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JiriSewa'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roles.map((r) => r.label).join(' · '),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Rider section
                  if (roles.contains(UserRole.rider) &&
                      _upcomingTrips.isNotEmpty) ...[
                    _sectionHeader('Upcoming Trips', Icons.route),
                    const SizedBox(height: 8),
                    ..._upcomingTrips.map(_buildTripCard),
                    const SizedBox(height: 24),
                  ],

                  // Farmer section
                  if (roles.contains(UserRole.farmer)) ...[
                    _sectionHeader('Farm Dashboard', Icons.agriculture),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      'Pending Pickups',
                      _pendingFarmerOrders.toString(),
                      Icons.local_shipping_outlined,
                      AppColors.accent,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recent orders
                  if (_recentOrders.isNotEmpty) ...[
                    _sectionHeader('Recent Orders', Icons.receipt_long),
                    const SizedBox(height: 8),
                    ..._recentOrders.map(_buildOrderCard),
                    const SizedBox(height: 24),
                  ],

                  // Nearby produce
                  if (_nearbyProduce.isNotEmpty) ...[
                    _sectionHeader('Fresh Produce', Icons.eco),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _nearbyProduce.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) =>
                            _buildProduceCard(_nearbyProduce[index]),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        subtitle: Text(label),
      ),
    );
  }

  Widget _buildOrderCard(models.Order order) {
    return Card(
      child: ListTile(
        leading: Icon(
          order.status.isActive ? Icons.local_shipping : Icons.check_circle,
          color: order.status.isActive ? AppColors.primary : AppColors.secondary,
        ),
        title: Text(
          'Order #${order.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(order.status.label),
        trailing: Text(
          'NPR ${order.grandTotal.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ));
        },
      ),
    );
  }

  Widget _buildTripCard(RiderTrip trip) {
    return Card(
      child: ListTile(
        leading: Icon(
          trip.status == TripStatus.inTransit
              ? Icons.directions_car
              : Icons.schedule,
          color: trip.status == TripStatus.inTransit
              ? AppColors.secondary
              : AppColors.primary,
        ),
        title: Text(
          '${trip.originName} → ${trip.destinationName}',
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(trip.status.label),
        trailing: Text(
          '${trip.remainingCapacityKg.toStringAsFixed(0)} kg',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TripDetailScreen(tripId: trip.id),
          ));
        },
      ),
    );
  }

  Widget _buildProduceCard(ProduceListing listing) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProduceDetailScreen(listingId: listing.id),
        ));
      },
      child: SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 90,
                width: double.infinity,
                color: AppColors.muted,
                child: listing.photos.isNotEmpty
                    ? Image.network(listing.photos.first, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.eco, size: 40, color: AppColors.secondary))
                    : const Icon(Icons.eco, size: 40, color: AppColors.secondary),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    if (listing.farmerName != null)
                      Text(
                        listing.farmerName!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
