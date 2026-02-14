import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';

/// Screen for riders to view and accept/decline matched orders for their trips.
class OrderAcceptanceScreen extends StatefulWidget {
  final String tripId;

  const OrderAcceptanceScreen({super.key, required this.tripId});

  @override
  State<OrderAcceptanceScreen> createState() => _OrderAcceptanceScreenState();
}

class _OrderAcceptanceScreenState extends State<OrderAcceptanceScreen> {
  final _supabase = Supabase.instance.client;

  List<models.Order> _pendingOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    setState(() => _loading = true);

    try {
      // Find pending orders that could be matched to this trip
      final data = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
          .eq('status', OrderStatus.pending.dbValue)
          .isFilter('rider_trip_id', null)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        _pendingOrders = (data as List)
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
      appBar: AppBar(title: const Text('Available Orders')),
      body: RefreshIndicator(
        onRefresh: _loadPendingOrders,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pendingOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No pending orders available',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildOrderCard(_pendingOrders[index]),
                  ),
      ),
    );
  }

  Widget _buildOrderCard(models.Order order) {
    final itemNames = order.items.map((i) => i.listingName('en')).join(', ');
    final totalWeight =
        order.items.fold(0.0, (sum, i) => sum + i.quantityKg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemNames,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(order.consumerName ?? 'Consumer',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.deliveryAddress,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.fitness_center, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${totalWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const Spacer(),
                Text('NPR ${order.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineOrder(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOrder(order),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOrder(models.Order order) async {
    final auth = context.read<AuthProvider>();

    try {
      await _supabase.from('orders').update({
        'status': OrderStatus.matched.dbValue,
        'rider_trip_id': widget.tripId,
        'rider_id': auth.userId,
      }).eq('id', order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted!')),
      );
      _loadPendingOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept order: $e')),
      );
    }
  }

  Future<void> _declineOrder(models.Order order) async {
    // Just remove from list — no DB change since it's still pending
    setState(() {
      _pendingOrders.remove(order);
    });
  }
}
