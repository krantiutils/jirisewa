import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';
import 'package:jirisewa_mobile/features/trips/providers/trip_detail_provider.dart';
import 'package:jirisewa_mobile/features/trips/providers/trips_provider.dart';
import 'package:jirisewa_mobile/features/trips/repositories/trip_repository.dart';

/// Trip detail screen showing route map, matched orders, trip stops with
/// sequence, and context-dependent action buttons.
class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  String? _actionInProgress;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        title: detailAsync.whenOrNull(
          data: (data) => Text(
            '${data.trip['origin_name'] ?? '?'} \u2192 ${data.trip['destination_name'] ?? '?'}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          if (detailAsync.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _statusChip(
                  detailAsync.value!.trip['status'] as String? ?? 'scheduled',
                ),
              ),
            ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load trip: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(tripDetailProvider(widget.tripId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(TripDetailData data) {
    final trip = data.trip;
    final stops = data.stops;
    final orders = data.orders;
    final status = trip['status'] as String? ?? 'scheduled';
    final origin = _coordinatesForPoint(trip['origin']) ??
        _coordinatesForPlace(trip['origin_name'] as String?);
    final destination = _coordinatesForPoint(trip['destination']) ??
        _coordinatesForPlace(trip['destination_name'] as String?);

    return RefreshIndicator(
      onRefresh: () =>
          ref.refresh(tripDetailProvider(widget.tripId).future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Route Map
            ClipRRect(
              child: SizedBox(
                height: 220,
                child: RouteMapWidget(
                  origin: origin,
                  destination: destination,
                  originName: trip['origin_name'] as String?,
                  destinationName: trip['destination_name'] as String?,
                  isActive: status == 'in_transit',
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trip Info Card
                  _buildTripInfoCard(trip, stops),
                  const SizedBox(height: 24),

                  // Trip Stops Section
                  if (stops.isNotEmpty) ...[
                    _sectionTitle('Trip Stops'),
                    const SizedBox(height: 8),
                    ...stops.map((stop) => _buildStopTile(stop)),
                    const SizedBox(height: 24),
                  ],

                  // Matched Orders Section
                  if (orders.isNotEmpty) ...[
                    _sectionTitle('Matched Orders'),
                    const SizedBox(height: 8),
                    ...orders.map(
                      (order) => _buildOrderCard(order, status),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    _sectionTitle('Matched Orders'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'No orders matched to this trip yet.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  _buildActionButtons(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trip Info Card
  // ---------------------------------------------------------------------------

  Widget _buildTripInfoCard(
    Map<String, dynamic> trip,
    List<Map<String, dynamic>> stops,
  ) {
    final status = trip['status'] as String? ?? 'scheduled';
    final departureAt = trip['departure_at'] as String?;
    final remaining =
        (trip['remaining_capacity_kg'] as num?)?.toDouble() ?? 0;
    final total =
        (trip['available_capacity_kg'] as num?)?.toDouble() ?? 0;
    final used = total - remaining;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  departureAt != null
                      ? _formatDateTime(departureAt)
                      : 'No departure time',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.fitness_center, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                '${used.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} kg used',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (used / total).clamp(0.0, 1.0) : 0,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                total > 0 && used / total > 0.85
                    ? AppColors.error
                    : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.pin_drop, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                '${stops.length} stop${stops.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${stops.where((s) => s['completed'] == true).length} completed',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trip Stops
  // ---------------------------------------------------------------------------

  Widget _buildStopTile(Map<String, dynamic> stop) {
    final sequence = (stop['sequence_order'] as num?)?.toInt() ?? 0;
    final type = stop['type'] as String? ?? 'pickup';
    final isCompleted = stop['completed'] == true;
    final estimatedArrival = stop['estimated_arrival'] as String?;
    final isPickup = type == 'pickup';

    // Try to get a location name from order references or stop data
    final locationName = stop['address'] as String? ??
        stop['location_name'] as String? ??
        '${_formatStopType(type)} #${sequence + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.secondary.withAlpha(15)
            : AppColors.muted,
        borderRadius: BorderRadius.circular(8),
        border: isCompleted
            ? Border.all(color: AppColors.secondary.withAlpha(60))
            : null,
      ),
      child: Row(
        children: [
          // Sequence number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.secondary
                  : isPickup
                      ? AppColors.accent.withAlpha(30)
                      : AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${sequence + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPickup ? AppColors.accent : AppColors.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Stop type icon
          Icon(
            isPickup ? Icons.agriculture : Icons.local_shipping,
            size: 20,
            color: isPickup ? AppColors.accent : AppColors.primary,
          ),
          const SizedBox(width: 8),

          // Stop info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (estimatedArrival != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ETA: ${_formatTime(estimatedArrival)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPickup
                  ? AppColors.accent.withAlpha(25)
                  : AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatStopType(type),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPickup ? AppColors.accent : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Matched Orders
  // ---------------------------------------------------------------------------

  Widget _buildOrderCard(Map<String, dynamic> order, String tripStatus) {
    final orderId = order['id'] as String? ?? '';
    final orderStatus = order['status'] as String? ?? 'pending';
    final deliveryAddress =
        order['delivery_address'] as String? ?? 'No address';
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final items = order['order_items'] as List<dynamic>? ?? [];

    // Group items by farmer_id for per-farmer actions
    final farmerGroups = <String, List<Map<String, dynamic>>>{};
    for (final rawItem in items) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final farmerId = item['farmer_id'] as String? ?? 'unknown';
      farmerGroups.putIfAbsent(farmerId, () => []).add(item);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            deliveryAddress,
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _orderStatusBadge(orderStatus),
                  const SizedBox(height: 4),
                  Text(
                    'Rs ${(totalPrice + deliveryFee).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Per-farmer item groups with actions
          if (farmerGroups.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: 12),
            ...farmerGroups.entries.map(
              (entry) => _buildFarmerGroup(
                orderId: orderId,
                farmerId: entry.key,
                items: entry.value,
                tripStatus: tripStatus,
                orderStatus: orderStatus,
              ),
            ),
          ],

          // Start delivery button (per-order, when trip is in_transit)
          if (tripStatus == 'in_transit' &&
              orderStatus == 'matched' &&
              _allItemsPickedUp(items)) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _actionInProgress != null
                    ? null
                    : () => _startDelivery(orderId),
                icon: _actionInProgress == 'start_delivery_$orderId'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_shipping, size: 18),
                label: Text(
                  _actionInProgress == 'start_delivery_$orderId'
                      ? 'Starting...'
                      : 'Start Delivery',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFarmerGroup({
    required String orderId,
    required String farmerId,
    required List<Map<String, dynamic>> items,
    required String tripStatus,
    required String orderStatus,
  }) {
    final allPickedUp = items.every(
      (item) => (item['pickup_status'] as String?) == 'picked_up',
    );
    final allUnavailable = items.every(
      (item) => (item['pickup_status'] as String?) == 'unavailable',
    );
    final isResolved = allPickedUp || allUnavailable;
    final farmerShortId =
        farmerId.length > 8 ? farmerId.substring(0, 8) : farmerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farmer header
          Row(
            children: [
              Icon(
                Icons.agriculture,
                size: 16,
                color: allPickedUp
                    ? AppColors.secondary
                    : allUnavailable
                        ? AppColors.error
                        : AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Farmer $farmerShortId',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (allPickedUp)
                _pickupBadge('Picked up', AppColors.secondary)
              else if (allUnavailable)
                _pickupBadge('Unavailable', AppColors.error)
              else
                _pickupBadge('Pending', Colors.grey),
            ],
          ),
          const SizedBox(height: 6),

          // Item list
          ...items.map((item) {
            final listing =
                item['produce_listings'] as Map<String, dynamic>?;
            final name = listing?['name_en'] as String? ?? 'Unknown';
            final qty = item['quantity_kg'] as num? ?? 0;
            final price = item['price_per_kg'] as num? ?? 0;
            final pickupStatus =
                item['pickup_status'] as String? ?? 'pending_pickup';

            return Padding(
              padding: const EdgeInsets.only(left: 22, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$name (${qty}kg x Rs $price)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        decoration: pickupStatus == 'unavailable'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  _itemPickupIcon(pickupStatus),
                ],
              ),
            );
          }),

          // Per-farmer action buttons
          if (tripStatus == 'in_transit' && !isResolved) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _actionInProgress != null
                        ? null
                        : () =>
                            _markItemsUnavailable(orderId, farmerId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(36),
                    ),
                    child: Text(
                      _actionInProgress ==
                              'unavailable_${orderId}_$farmerId'
                          ? 'Marking...'
                          : 'Unavailable',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _actionInProgress != null
                        ? null
                        : () =>
                            _confirmFarmerPickup(orderId, farmerId),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      minimumSize: const Size.fromHeight(36),
                    ),
                    child: Text(
                      _actionInProgress ==
                              'pickup_${orderId}_$farmerId'
                          ? 'Confirming...'
                          : 'Confirm Pickup',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action Buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(String status) {
    switch (status) {
      case 'scheduled':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _actionInProgress != null
                  ? null
                  : () => _startTrip(),
              icon: _actionInProgress == 'start_trip'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _actionInProgress == 'start_trip'
                    ? 'Starting...'
                    : 'Start Trip',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _actionInProgress != null
                  ? null
                  : () => _cancelTrip(),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(
                _actionInProgress == 'cancel_trip'
                    ? 'Cancelling...'
                    : 'Cancel Trip',
              ),
            ),
          ],
        );
      case 'in_transit':
        return FilledButton.icon(
          onPressed: _actionInProgress != null
              ? null
              : () => _completeTrip(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
          ),
          icon: _actionInProgress == 'complete_trip'
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),
          label: Text(
            _actionInProgress == 'complete_trip'
                ? 'Completing...'
                : 'Complete Trip',
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _startTrip() async {
    await _performAction('start_trip', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.startTrip(widget.tripId);
    });
  }

  Future<void> _completeTrip() async {
    await _performAction('complete_trip', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.completeTrip(widget.tripId);
    });
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: const Text(
          'Are you sure you want to cancel this trip? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _performAction('cancel_trip', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.cancelTrip(widget.tripId);
    });
  }

  Future<void> _confirmFarmerPickup(
      String orderId, String farmerId) async {
    await _performAction('pickup_${orderId}_$farmerId', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.confirmFarmerPickup(orderId, farmerId);
    });
  }

  Future<void> _markItemsUnavailable(
      String orderId, String farmerId) async {
    await _performAction('unavailable_${orderId}_$farmerId', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.markItemsUnavailable(orderId, farmerId);
    });
  }

  Future<void> _startDelivery(String orderId) async {
    await _performAction('start_delivery_$orderId', () async {
      final repo = ref.read(tripRepositoryProvider);
      await repo.startDelivery(orderId);
    });
  }

  /// Generic action handler with loading state, error handling, and refresh.
  Future<void> _performAction(
    String actionKey,
    Future<void> Function() action,
  ) async {
    setState(() => _actionInProgress = actionKey);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(tripDetailProvider(widget.tripId));
      ref.invalidate(tripsDataProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actionInProgress = null);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Widget _orderStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _orderStatusColor(status).withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _orderStatusColor(status),
        ),
      ),
    );
  }

  Widget _pickupBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _itemPickupIcon(String pickupStatus) {
    switch (pickupStatus) {
      case 'picked_up':
        return const Icon(Icons.check_circle, size: 16, color: AppColors.secondary);
      case 'unavailable':
        return const Icon(Icons.cancel, size: 16, color: AppColors.error);
      default:
        return Icon(Icons.circle_outlined, size: 16, color: Colors.grey[400]);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _allItemsPickedUp(List<dynamic> items) {
    if (items.isEmpty) return false;
    return items.every((item) {
      final map = item as Map;
      final status = map['pickup_status'] as String?;
      return status == 'picked_up' || status == 'unavailable';
    });
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) =>
              w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  String _formatStopType(String type) {
    switch (type) {
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      default:
        return _formatStatus(type);
    }
  }

  String _formatDateTime(String isoString) {
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $amPm';
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

  Color _statusColor(String status) {
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

  Color _orderStatusColor(String status) {
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

  LatLng? _coordinatesForPoint(dynamic value) {
    return TripRepository.parsePoint(value);
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
