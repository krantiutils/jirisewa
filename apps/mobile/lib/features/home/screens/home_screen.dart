import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

/// Context-aware home dashboard.
///
/// - Consumer: recent orders + nearby produce summary
/// - Rider: upcoming trips + matched orders
/// - Farmer: active listings + pending orders
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  // Consumer data
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _nearbyProduce = [];

  // Rider data
  List<Map<String, dynamic>> _upcomingTrips = [];
  List<Map<String, dynamic>> _matchedOrders = [];

  // Farmer data
  List<Map<String, dynamic>> _activeListings = [];
  List<Map<String, dynamic>> _pendingOrders = [];

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final session = SessionProvider.of(context);
    final currentProfile = session.profile;
    if (!session.isAuthenticated || currentProfile == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = currentProfile.id;

      switch (session.activeRole) {
        case 'consumer':
          final orders = await _supabase
              .from('orders')
              .select('id, status, total_price, delivery_fee, created_at')
              .eq('consumer_id', userId)
              .order('created_at', ascending: false)
              .limit(5);
          final produce = await _supabase
              .from('produce_listings')
              .select('id, name_en, name_ne, price_per_kg, available_qty_kg, photos')
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(6);
          _recentOrders = List<Map<String, dynamic>>.from(orders);
          _nearbyProduce = List<Map<String, dynamic>>.from(produce);

        case 'rider':
          final trips = await _supabase
              .from('rider_trips')
              .select('id, origin_name, destination_name, departure_at, status, remaining_capacity_kg')
              .eq('rider_id', userId)
              .inFilter('status', ['scheduled', 'in_transit'])
              .order('departure_at')
              .limit(5);
          final orders = await _supabase
              .from('orders')
              .select('id, status, total_price, delivery_fee, delivery_address, created_at')
              .eq('rider_id', userId)
              .inFilter('status', ['matched', 'picked_up', 'in_transit'])
              .order('created_at', ascending: false)
              .limit(5);
          _upcomingTrips = List<Map<String, dynamic>>.from(trips);
          _matchedOrders = List<Map<String, dynamic>>.from(orders);

        case 'farmer':
          final listings = await _supabase
              .from('produce_listings')
              .select('id, name_en, name_ne, price_per_kg, available_qty_kg')
              .eq('farmer_id', userId)
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(5);
          final orders = await _supabase
              .from('order_items')
              .select('id, quantity_kg, price_per_kg, subtotal, pickup_confirmed, order_id')
              .eq('farmer_id', userId)
              .eq('pickup_confirmed', false)
              .limit(5);
          _activeListings = List<Map<String, dynamic>>.from(listings);
          _pendingOrders = List<Map<String, dynamic>>.from(orders);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load dashboard: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionProvider.of(context);
    final profile = session.profile;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(profile?.name ?? ''),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleSubtitle(session.activeRole),
                        style: TextStyle(
                          color: _roleColor(session.activeRole),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadDashboard,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._buildRoleContent(context, session.activeRole),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRoleContent(BuildContext context, String role) {
    switch (role) {
      case 'rider':
        return _buildRiderContent(context);
      case 'farmer':
        return _buildFarmerContent(context);
      default:
        return _buildConsumerContent(context);
    }
  }

  // -- Consumer dashboard --

  List<Widget> _buildConsumerContent(BuildContext context) {
    return [
      _sectionHeader('Recent Orders', onViewAll: () => context.go(AppRoutes.orders)),
      if (_recentOrders.isEmpty)
        _emptyState('No orders yet', 'Browse the marketplace to find fresh produce')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _orderTile(_recentOrders[i]),
            childCount: _recentOrders.length,
          ),
        ),
      _sectionHeader('Fresh Produce', onViewAll: () => context.go(AppRoutes.marketplace)),
      if (_nearbyProduce.isEmpty)
        _emptyState('No produce available', 'Check back later for new listings')
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _produceTile(_nearbyProduce[i]),
              childCount: _nearbyProduce.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Rider dashboard --

  List<Widget> _buildRiderContent(BuildContext context) {
    return [
      _sectionHeader('Upcoming Trips', onViewAll: () => context.go(AppRoutes.trips)),
      if (_upcomingTrips.isEmpty)
        _emptyState('No upcoming trips', 'Post a trip to start earning')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _tripTile(_upcomingTrips[i]),
            childCount: _upcomingTrips.length,
          ),
        ),
      _sectionHeader('Matched Orders', onViewAll: () => context.go(AppRoutes.orders)),
      if (_matchedOrders.isEmpty)
        _emptyState('No matched orders', 'Orders will appear when matched to your trips')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _orderTile(_matchedOrders[i]),
            childCount: _matchedOrders.length,
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Farmer dashboard --

  List<Widget> _buildFarmerContent(BuildContext context) {
    return [
      _sectionHeader('Active Listings', onViewAll: () => context.go(AppRoutes.marketplace)),
      if (_activeListings.isEmpty)
        _emptyState('No active listings', 'List your produce to start selling')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _listingTile(_activeListings[i]),
            childCount: _activeListings.length,
          ),
        ),
      _sectionHeader('Pending Pickups'),
      if (_pendingOrders.isEmpty)
        _emptyState('No pending pickups', 'Orders awaiting pickup will appear here')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _pickupTile(_pendingOrders[i]),
            childCount: _pendingOrders.length,
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Shared tile builders --

  Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderTile(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _statusColor(status).withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.receipt_long, color: _statusColor(status), size: 20),
      ),
      title: Text(
        'Order #${(order['id'] as String).substring(0, 8)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        _formatStatus(status),
        style: TextStyle(fontSize: 13, color: _statusColor(status)),
      ),
      trailing: Text(
        'Rs ${order['total_price'] ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () => context.go('${AppRoutes.orders}/${order['id']}'),
    );
  }

  Widget _tripTile(Map<String, dynamic> trip) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.route, color: AppColors.accent, size: 20),
      ),
      title: Text(
        '${trip['origin_name'] ?? '?'} → ${trip['destination_name'] ?? '?'}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${trip['remaining_capacity_kg'] ?? 0} kg available',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
    );
  }

  Widget _produceTile(Map<String, dynamic> produce) {
    final photos = produce['photos'] as List?;
    final hasPhoto = photos != null && photos.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: hasPhoto
                ? Image.network(photos.first as String, fit: BoxFit.cover, width: double.infinity)
                : Container(
                    color: AppColors.secondary.withAlpha(25),
                    child: const Center(child: Icon(Icons.eco, color: AppColors.secondary, size: 32)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (produce['name_en'] as String?) ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${produce['price_per_kg'] ?? 0}/kg',
                  style: TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingTile(Map<String, dynamic> listing) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.secondary.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.eco, color: AppColors.secondary, size: 20),
      ),
      title: Text(
        (listing['name_en'] as String?) ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${listing['available_qty_kg'] ?? 0} kg available',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: Text(
        'Rs ${listing['price_per_kg'] ?? 0}/kg',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _pickupTile(Map<String, dynamic> item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2, color: AppColors.accent, size: 20),
      ),
      title: Text(
        '${item['quantity_kg'] ?? 0} kg • Rs ${item['subtotal'] ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'Awaiting pickup',
        style: TextStyle(fontSize: 13, color: AppColors.accent),
      ),
    );
  }

  // -- Helpers --

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return name.isNotEmpty ? '$timeGreeting, ${name.split(' ').first}' : timeGreeting;
  }

  String _roleSubtitle(String role) {
    switch (role) {
      case 'rider':
        return 'Rider Dashboard';
      case 'farmer':
        return 'Farmer Dashboard';
      default:
        return 'Consumer Dashboard';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'rider':
        return AppColors.accent;
      case 'farmer':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
    ).join(' ');
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
