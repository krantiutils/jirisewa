import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';

/// Order detail screen with fulfillment flow:
/// Farmer pickup -> Rider transit -> Customer delivery.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  LatLng? _riderLocation;
  DateTime? _lastRiderUpdateAt;
  RealtimeChannel? _trackingChannel;
  Timer? _staleTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _stopTrackingSubscription();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order = await _supabase
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .maybeSingle();

      if (order == null) {
        setState(() {
          _error = 'Order not found';
          _loading = false;
        });
        return;
      }

      final items = await _supabase
          .from('order_items')
          .select('*, produce_listings(name_en, name_ne)')
          .eq('order_id', widget.orderId);

      final castOrder = Map<String, dynamic>.from(order);
      final castItems = List<Map<String, dynamic>>.from(items);

      setState(() {
        _order = castOrder;
        _items = castItems;
        _loading = false;
      });

      await _setupTracking(castOrder);
    } catch (e) {
      setState(() {
        _error = 'Failed to load order: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _pickupPoint();
    final delivery = _deliveryPoint();
    final status = _order?['status'] as String? ?? 'pending';
    final isTrackingActive = status == 'picked_up' || status == 'in_transit';
    final isSignalStale =
        _lastRiderUpdateAt != null &&
        DateTime.now().difference(_lastRiderUpdateAt!).inSeconds > 30;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadOrder,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrder,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusBadge(_order!['status'] as String? ?? 'pending'),
                    const SizedBox(height: 16),

                    _sectionTitle('Fulfillment Map'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 200,
                        child: RouteMapWidget(
                          origin: pickup,
                          destination: delivery,
                          originName: 'Farmer pickup',
                          destinationName: 'Customer delivery',
                          currentPosition: _riderLocation,
                          isActive:
                              (_order!['status'] as String? ?? '') ==
                              'in_transit',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isTrackingActive)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSignalStale
                              ? Colors.amber.withAlpha(28)
                              : AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSignalStale ? Icons.wifi_off : Icons.navigation,
                              size: 16,
                              color: isSignalStale
                                  ? Colors.amber[800]
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _riderLocation == null
                                    ? 'Waiting for rider GPS signal...'
                                    : isSignalStale
                                    ? 'Rider signal is stale (>30s).'
                                    : 'Live rider location active.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSignalStale
                                      ? Colors.amber[900]
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _flowChips(),
                    const SizedBox(height: 24),

                    _sectionTitle('Delivery'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _order!['delivery_address'] as String? ??
                                      'No address',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (_order!['payment_method'] as String? ?? 'cash')
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatPaymentStatus(
                                  _order!['payment_status'] as String? ??
                                      'pending',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('Items'),
                    const SizedBox(height: 8),
                    if (_items.isEmpty)
                      const Text(
                        'No items',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ..._items.map(_itemTile),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _totalRow(
                            'Produce',
                            'Rs ${_order!['total_price'] ?? 0}',
                          ),
                          const SizedBox(height: 4),
                          _totalRow(
                            'Delivery',
                            'Rs ${_order!['delivery_fee'] ?? 0}',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              height: 2,
                              color: AppColors.border,
                            ),
                          ),
                          _totalRow(
                            'Total',
                            'Rs ${(((_order!['total_price'] as num?)?.toDouble() ?? 0) + ((_order!['delivery_fee'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
                            bold: true,
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

  Widget _statusBadge(String status) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _statusColor(status).withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _formatStatus(status),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _statusColor(status),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _flowChips() {
    final anyPicked = _items.any((item) => item['pickup_confirmed'] == true);
    final allDelivered =
        _items.isNotEmpty &&
        _items.every((item) => item['delivery_confirmed'] == true);
    final inTransit = (_order?['status'] as String? ?? '') == 'in_transit';

    final steps = [
      ('Farmer ready', anyPicked, AppColors.secondary),
      ('Rider in transit', inTransit, AppColors.accent),
      ('Customer delivered', allDelivered, AppColors.primary),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: steps.map((step) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: step.$2 ? step.$3.withAlpha(35) : Colors.grey.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            step.$1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: step.$2 ? step.$3 : Colors.grey[700],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final listing = item['produce_listings'] as Map<String, dynamic>?;
    final name = listing?['name_en'] as String? ?? 'Unknown';
    final qty = item['quantity_kg'] as num? ?? 0;
    final price = item['price_per_kg'] as num? ?? 0;
    final subtotal = item['subtotal'] as num? ?? 0;
    final pickedUp = item['pickup_confirmed'] as bool? ?? false;
    final delivered = item['delivery_confirmed'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${qty}kg × Rs $price',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (pickedUp)
                      _badge('Picked up', AppColors.accent)
                    else
                      _badge('Awaiting pickup', Colors.grey),
                    const SizedBox(width: 6),
                    if (delivered) _badge('Delivered', AppColors.secondary),
                  ],
                ),
              ],
            ),
          ),
          Text(
            'Rs $subtotal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
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

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
      ],
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

  String _formatPaymentStatus(String status) {
    return _formatStatus(status);
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

  LatLng _pickupPoint() {
    if (_items.isNotEmpty) {
      final first = _items.first;
      final pickupLocation = first['pickup_location'];
      final fromPickup = _tryParsePoint(pickupLocation);
      if (fromPickup != null) return fromPickup;
    }
    return const LatLng(27.6306, 86.2305);
  }

  LatLng _deliveryPoint() {
    final fromDeliveryGeo = _tryParsePoint(_order?['delivery_location']);
    if (fromDeliveryGeo != null) return fromDeliveryGeo;
    return _addressToLatLng(_order?['delivery_address'] as String?);
  }

  LatLng _addressToLatLng(String? address) {
    final lower = (address ?? '').toLowerCase();
    if (lower.contains('kathmandu')) return const LatLng(27.7172, 85.3240);
    if (lower.contains('banepa')) return const LatLng(27.6298, 85.5215);
    if (lower.contains('charikot')) return const LatLng(27.6681, 86.0290);
    if (lower.contains('jiri')) return const LatLng(27.6306, 86.2305);
    return jiriCenter;
  }

  LatLng? _tryParsePoint(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      // PostGIS WKT: POINT(lng lat)
      final pointMatch = RegExp(
        r'^POINT\(([-\d.]+)\s+([-\d.]+)\)$',
      ).firstMatch(trimmed);
      if (pointMatch != null) {
        final lng = double.tryParse(pointMatch.group(1)!);
        final lat = double.tryParse(pointMatch.group(2)!);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }

      // GeoJSON-like payload: {"type":"Point","coordinates":[lng,lat]}
      if (trimmed.startsWith('{') && trimmed.contains('coordinates')) {
        final coordsMatch = RegExp(
          r'"coordinates"\s*:\s*\[\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\]',
        ).firstMatch(trimmed);
        if (coordsMatch != null) {
          final lng = double.tryParse(coordsMatch.group(1)!);
          final lat = double.tryParse(coordsMatch.group(2)!);
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    }

    if (value is Map<String, dynamic>) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  Future<void> _setupTracking(Map<String, dynamic> order) async {
    _stopTrackingSubscription();

    final tripId = order['rider_trip_id'] as String?;
    final status = order['status'] as String? ?? 'pending';
    final shouldTrack =
        tripId != null && (status == 'picked_up' || status == 'in_transit');

    if (!shouldTrack) {
      if (mounted) {
        setState(() {
          _riderLocation = null;
          _lastRiderUpdateAt = null;
        });
      }
      return;
    }

    try {
      // Seed UI with latest known rider point before subscribing.
      final latest = await _supabase
          .from('rider_location_log')
          .select('location, recorded_at')
          .eq('trip_id', tripId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latest != null) {
        final point = _tryParsePoint(latest['location']);
        if (mounted && point != null) {
          setState(() {
            _riderLocation = point;
            _lastRiderUpdateAt = DateTime.tryParse(
              (latest['recorded_at'] as String?) ?? '',
            );
          });
        }
      }
    } catch (_) {
      // Best effort - live updates will still work even if seed lookup fails.
    }

    _trackingChannel = _supabase
        .channel('order_tracking_${widget.orderId}_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rider_location_log',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final point = _tryParsePoint(row['location']);
            if (!mounted || point == null) return;
            setState(() {
              _riderLocation = point;
              _lastRiderUpdateAt =
                  DateTime.tryParse(row['recorded_at']?.toString() ?? '') ??
                  DateTime.now();
            });
          },
        )
        .subscribe();

    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _lastRiderUpdateAt == null) return;
      // Tick UI so stale signal label updates without waiting for new events.
      setState(() {});
    });
  }

  void _stopTrackingSubscription() {
    _staleTimer?.cancel();
    _staleTimer = null;

    final channel = _trackingChannel;
    _trackingChannel = null;
    if (channel != null) {
      _supabase.removeChannel(channel);
    }
  }
}
