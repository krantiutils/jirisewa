import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';

/// Shows orders containing the farmer's produce, with pickup scheduling info.
class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _orderItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('order_items')
          .select(
              '*, listing:produce_listings(name_en, name_ne), order:orders(id, status, delivery_address, consumer_id, rider_id, created_at, consumer:users!consumer_id(name), rider:users!rider_id(name))')
          .eq('farmer_id', userId)
          .order('pickup_confirmed')
          .limit(50);

      if (!mounted) return;

      setState(() {
        _orderItems = List<Map<String, dynamic>>.from(data as List);
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
        title: const Text('My Orders'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orderItems.isEmpty
                ? const Center(
                    child: Text('No orders for your produce yet',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orderItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildOrderItemCard(_orderItems[index]),
                  ),
      ),
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> itemJson) {
    final listing = itemJson['listing'] as Map<String, dynamic>?;
    final order = itemJson['order'] as Map<String, dynamic>?;
    final pickupConfirmed = itemJson['pickup_confirmed'] as bool? ?? false;
    final quantityKg = (itemJson['quantity_kg'] as num).toDouble();
    final subtotal = (itemJson['subtotal'] as num).toDouble();
    final produceName = listing?['name_en'] as String? ?? 'Produce';
    final orderStatus = order?['status'] as String? ?? 'pending';
    final consumerData = order?['consumer'] as Map<String, dynamic>?;
    final riderData = order?['rider'] as Map<String, dynamic>?;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pickupConfirmed ? Icons.check_circle : Icons.pending,
                  size: 20,
                  color: pickupConfirmed
                      ? AppColors.secondary
                      : AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    produceName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(
                  pickupConfirmed ? 'Picked Up' : 'Awaiting Pickup',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: pickupConfirmed
                        ? AppColors.secondary
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${quantityKg.toStringAsFixed(1)} kg — NPR ${subtotal.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            Text(
              'Order status: ${OrderStatus.fromDb(orderStatus).label}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (consumerData != null)
              Text(
                'Consumer: ${consumerData['name']}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            if (riderData != null)
              Text(
                'Rider: ${riderData['name']}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            if (order?['created_at'] != null)
              Text(
                'Ordered: ${dateFormat.format(DateTime.parse(order!['created_at'] as String).toLocal())}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}
