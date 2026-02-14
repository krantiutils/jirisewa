import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/models/rider_trip.dart';
import '../../../core/theme.dart';

/// Active trip screen: rider follows their route, confirms pickups and deliveries.
class ActiveTripScreen extends StatefulWidget {
  final String tripId;

  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  RiderTrip? _trip;
  List<models.Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final tripData = await _supabase
          .from('rider_trips')
          .select('*, rider:users!rider_id(name, phone, rating_avg)')
          .eq('id', widget.tripId)
          .single();

      final ordersData = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
          .eq('rider_trip_id', widget.tripId)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        _trip = RiderTrip.fromJson(tripData);
        _orders = (ordersData as List)
            .map((j) => models.Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Trip'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Trip status banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.secondary.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: AppColors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trip In Progress',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary)),
                    Text(
                      '${trip.originName.split(',').first} → ${trip.destinationName.split(',').first}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Pickup / delivery sequence
        Text('Stops (${_orders.length} orders)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        if (_orders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No orders to pick up on this trip.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._orders.expand((order) => [
                _buildOrderStop(order),
                const SizedBox(height: 8),
              ]),

        const SizedBox(height: 24),

        // Complete trip button
        ElevatedButton.icon(
          onPressed: _allDelivered ? () => _completeTrip() : null,
          icon: const Icon(Icons.check_circle),
          label: const Text('Complete Trip'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
          ),
        ),
        if (!_allDelivered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Complete all pickups and deliveries to finish the trip.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  bool get _allDelivered {
    if (_orders.isEmpty) return true;
    return _orders.every((o) =>
        o.status == OrderStatus.delivered ||
        o.status == OrderStatus.cancelled);
  }

  Widget _buildOrderStop(models.Order order) {
    final itemNames = order.items.map((i) => i.listingName('en')).join(', ');
    final allPickedUp = order.items.every((i) => i.pickupConfirmed);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _orderStatusIcon(order.status),
                  color: _orderStatusColor(order.status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(order.status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _orderStatusColor(order.status))),
              ],
            ),
            const SizedBox(height: 4),
            Text(itemNames,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Text('To: ${order.consumerName ?? order.deliveryAddress}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),

            // Action buttons based on order status
            if (order.status == OrderStatus.matched) ...[
              ElevatedButton.icon(
                onPressed: () => _confirmPickup(order),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Confirm Pickup (Photo)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            if (order.status == OrderStatus.pickedUp ||
                (order.status == OrderStatus.inTransit && allPickedUp)) ...[
              ElevatedButton.icon(
                onPressed: () => _confirmDelivery(order),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm Delivery'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: AppColors.secondary,
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _orderStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.matched:
        return Icons.inventory;
      case OrderStatus.pickedUp:
        return Icons.local_shipping;
      case OrderStatus.inTransit:
        return Icons.directions_car;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  Color _orderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.matched:
        return AppColors.primary;
      case OrderStatus.pickedUp:
      case OrderStatus.inTransit:
        return AppColors.accent;
      case OrderStatus.delivered:
        return AppColors.secondary;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmPickup(models.Order order) async {
    // Take photo for pickup confirmation
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (photo == null) return;

    try {
      // Upload photo to Supabase Storage
      final bytes = await photo.readAsBytes();
      final fileName =
          'pickups/${order.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('produce-photos')
          .uploadBinary(fileName, bytes);

      final photoUrl =
          _supabase.storage.from('produce-photos').getPublicUrl(fileName);

      // Update order items with pickup confirmation
      for (final item in order.items) {
        await _supabase.from('order_items').update({
          'pickup_confirmed': true,
          'pickup_photo_url': photoUrl,
        }).eq('id', item.id);
      }

      // Update order status
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.pickedUp.dbValue})
          .eq('id', order.id);

      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm pickup: $e')),
      );
    }
  }

  Future<void> _confirmDelivery(models.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: const Text(
            'Confirm that the produce has been delivered to the consumer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update order items
      for (final item in order.items) {
        await _supabase.from('order_items').update({
          'delivery_confirmed': true,
        }).eq('id', item.id);
      }

      // Update order status
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.delivered.dbValue})
          .eq('id', order.id);

      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm delivery: $e')),
      );
    }
  }

  Future<void> _completeTrip() async {
    try {
      await _supabase
          .from('rider_trips')
          .update({'status': TripStatus.completed.dbValue})
          .eq('id', widget.tripId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip completed!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete trip: $e')),
      );
    }
  }
}
