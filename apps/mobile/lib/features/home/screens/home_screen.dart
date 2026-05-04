import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/home/providers/home_provider.dart';

/// Context-aware home dashboard.
///
/// - Consumer: recent orders + nearby produce summary
/// - Rider: upcoming trips + matched orders
/// - Farmer: active listings + pending orders
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final role = ref.watch(activeRoleProvider);
    final dashboardAsync = ref.watch(homeDashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDashboardProvider);
            // Wait for the provider to complete after invalidation.
            await ref.read(homeDashboardProvider.future);
          },
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleSubtitle(role),
                        style: TextStyle(
                          color: _roleColor(role),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content based on async state
              ...dashboardAsync.when(
                loading: () => [
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text('Failed to load dashboard: $error',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () =>
                                  ref.invalidate(homeDashboardProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                data: (data) => _buildRoleContent(context, role, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Role content builders --

  static List<Widget> _buildRoleContent(
      BuildContext context, String role, HomeDashboardData data) {
    switch (role) {
      case 'rider':
        return _buildRiderContent(context, data);
      case 'farmer':
        return _buildFarmerContent(context, data);
      default:
        return _buildConsumerContent(context, data);
    }
  }

  // -- Consumer dashboard --

  static List<Widget> _buildConsumerContent(
      BuildContext context, HomeDashboardData data) {
    return [
      _sectionHeader('Recent Orders',
          onViewAll: () => context.go(AppRoutes.orders)),
      if (data.recentOrders.isEmpty)
        _emptyState(
            'No orders yet', 'Browse the marketplace to find fresh produce')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _orderTile(context, data.recentOrders[i]),
            childCount: data.recentOrders.length,
          ),
        ),
      _sectionHeader('Fresh Produce',
          onViewAll: () => context.go(AppRoutes.marketplace)),
      if (data.nearbyProduce.isEmpty)
        _emptyState('No produce available', 'Check back later for new listings')
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _produceTile(context, data.nearbyProduce[i]),
              childCount: data.nearbyProduce.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
          ),
        ),
      _sectionHeader('Quick Links'),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.primary),
                title: const Text('Saved Addresses'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push(AppRoutes.addresses),
              ),
            ],
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Rider dashboard --

  static List<Widget> _buildRiderContent(
      BuildContext context, HomeDashboardData data) {
    return [
      _sectionHeader('Upcoming Trips',
          onViewAll: () => context.go(AppRoutes.trips)),
      if (data.upcomingTrips.isEmpty)
        _emptyState('No upcoming trips', 'Post a trip to start earning')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _tripTile(context, data.upcomingTrips[i]),
            childCount: data.upcomingTrips.length,
          ),
        ),
      _sectionHeader('Matched Orders',
          onViewAll: () => context.go(AppRoutes.orders)),
      if (data.matchedOrders.isEmpty)
        _emptyState('No matched orders',
            'Orders will appear when matched to your trips')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _orderTile(context, data.matchedOrders[i]),
            childCount: data.matchedOrders.length,
          ),
        ),
      _sectionHeader('Quick Links'),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.local_shipping, color: AppColors.accent),
                title: const Text('Available Orders'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push(AppRoutes.availableOrders),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: AppColors.accent),
                title: const Text('Earnings'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push(AppRoutes.earnings),
              ),
            ],
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Farmer dashboard --

  static List<Widget> _buildFarmerContent(
      BuildContext context, HomeDashboardData data) {
    return [
      _sectionHeader('Active Listings',
          onViewAll: () => context.go(AppRoutes.marketplace)),
      if (data.activeListings.isEmpty)
        _emptyState(
            'No active listings', 'List your produce to start selling')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _listingTile(context, data.activeListings[i]),
            childCount: data.activeListings.length,
          ),
        ),
      _sectionHeader('Pending Pickups'),
      if (data.pendingOrders.isEmpty)
        _emptyState(
            'No pending pickups', 'Orders awaiting pickup will appear here')
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _pickupTile(context, data.pendingOrders[i]),
            childCount: data.pendingOrders.length,
          ),
        ),
      _sectionHeader('Quick Links'),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long, color: AppColors.secondary),
                title: const Text('My Orders'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push(AppRoutes.farmerOrders),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: AppColors.secondary),
                title: const Text('Earnings'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => context.push(AppRoutes.earnings),
              ),
            ],
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
    ];
  }

  // -- Shared tile builders --

  static Widget _sectionHeader(String title, {VoidCallback? onViewAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  static Widget _emptyState(String title, String subtitle) {
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
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _orderTile(
      BuildContext context, Map<String, dynamic> order) {
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
        child:
            Icon(Icons.receipt_long, color: _statusColor(status), size: 20),
      ),
      title: Text(
        'Order #${_shortId(order['id'] as String? ?? '')}',
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

  static Widget _tripTile(BuildContext context, Map<String, dynamic> trip) {
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
      onTap: () => context.push('/trips/${trip['id']}'),
    );
  }

  static Widget _produceTile(
      BuildContext context, Map<String, dynamic> produce) {
    final photos = produce['photos'] as List?;
    final hasPhoto = photos != null && photos.isNotEmpty;

    return GestureDetector(
      onTap: () =>
          context.push('/produce/${produce['id']}'),
      child: Container(
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
                  ? Image.network(photos.first as String,
                      fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: AppColors.secondary.withAlpha(25),
                      child: const Center(
                          child: Icon(Icons.eco,
                              color: AppColors.secondary, size: 32)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (produce['name_en'] as String?) ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rs ${produce['price_per_kg'] ?? 0}/kg',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _listingTile(
      BuildContext context, Map<String, dynamic> listing) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.secondary.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            const Icon(Icons.eco, color: AppColors.secondary, size: 20),
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
      onTap: () => context.push('/farmer/listings/${listing['id']}/edit'),
    );
  }

  static Widget _pickupTile(
      BuildContext context, Map<String, dynamic> item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2,
            color: AppColors.accent, size: 20),
      ),
      title: Text(
        '${item['quantity_kg'] ?? 0} kg \u2022 Rs ${item['subtotal'] ?? 0}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'Awaiting pickup',
        style: TextStyle(fontSize: 13, color: AppColors.accent),
      ),
      onTap: () {
        final orderId = item['order_id'] as String?;
        if (orderId != null) {
          context.push('${AppRoutes.orders}/$orderId');
        }
      },
    );
  }

  // -- Helpers --

  static String _shortId(String id) =>
      id.length > 8 ? id.substring(0, 8) : id;

  static String _greeting(String name) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return name.isNotEmpty
        ? '$timeGreeting, ${name.split(' ').first}'
        : timeGreeting;
  }

  static String _roleSubtitle(String role) {
    switch (role) {
      case 'rider':
        return 'Rider Dashboard';
      case 'farmer':
        return 'Farmer Dashboard';
      default:
        return 'Consumer Dashboard';
    }
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'rider':
        return AppColors.accent;
      case 'farmer':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  static String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  static Color _statusColor(String status) {
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
