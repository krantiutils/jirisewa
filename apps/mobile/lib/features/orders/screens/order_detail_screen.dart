import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../ratings/screens/rating_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _supabase = Supabase.instance.client;

  models.Order? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), rider:users!rider_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
          .eq('id', widget.orderId)
          .single();

      if (!mounted) return;
      setState(() {
        _order = models.Order.fromJson(data);
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
        title: Text(_order != null
            ? 'Order #${_order!.id.substring(0, 8)}'
            : 'Order'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : RefreshIndicator(
                  onRefresh: _loadOrder,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final auth = context.read<AuthProvider>();
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status timeline
        _buildStatusTimeline(order.status),
        const SizedBox(height: 24),

        // Order items
        Text('Items',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...order.items.map(_buildItemRow),
        const Divider(),
        _priceRow('Produce Total', order.totalPrice),
        _priceRow('Delivery Fee',
            order.deliveryFee > 0 ? order.deliveryFee : null,
            fallback: 'Pending'),
        const Divider(),
        _priceRow('Total', order.grandTotal, bold: true),
        const SizedBox(height: 24),

        // Delivery info
        Text('Delivery',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _infoRow(Icons.location_on, 'Address', order.deliveryAddress),
        _infoRow(Icons.payment, 'Payment', order.paymentMethod.label),
        _infoRow(Icons.schedule, 'Ordered',
            dateFormat.format(order.createdAt.toLocal())),

        // Rider info
        if (order.riderName != null) ...[
          const SizedBox(height: 16),
          Text('Rider',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.accent.withAlpha(30),
                child: const Icon(Icons.directions_bike,
                    color: AppColors.accent),
              ),
              title: Text(order.riderName!),
            ),
          ),
        ],

        // Consumer info (for rider/farmer view)
        if (order.consumerName != null &&
            auth.userId != order.consumerId) ...[
          const SizedBox(height: 16),
          Text('Consumer',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withAlpha(30),
                child:
                    const Icon(Icons.person, color: AppColors.primary),
              ),
              title: Text(order.consumerName!),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Actions
        if (order.status == OrderStatus.delivered &&
            auth.userId == order.consumerId)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RatingScreen(orderId: order.id),
              ));
            },
            icon: const Icon(Icons.star),
            label: const Text('Rate this delivery'),
          ),

        if (order.status == OrderStatus.pending &&
            auth.userId == order.consumerId)
          OutlinedButton(
            onPressed: () => _cancelOrder(order.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('Cancel Order'),
          ),
      ],
    );
  }

  Widget _buildStatusTimeline(OrderStatus current) {
    final steps = [
      OrderStatus.pending,
      OrderStatus.matched,
      OrderStatus.pickedUp,
      OrderStatus.inTransit,
      OrderStatus.delivered,
    ];

    final currentIdx = steps.indexOf(current);

    // Handle cancelled/disputed
    if (current == OrderStatus.cancelled || current == OrderStatus.disputed) {
      return Card(
        color: AppColors.error.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: AppColors.error),
              const SizedBox(width: 12),
              Text(current.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.error)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isComplete = index <= currentIdx;
        final isCurrent = index == currentIdx;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete ? AppColors.primary : AppColors.muted,
                    border: isCurrent
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                  ),
                  child: isComplete
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 32,
                    color: isComplete ? AppColors.primary : AppColors.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                step.label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isComplete ? AppColors.foreground : Colors.grey,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildItemRow(models.OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.listingName('en'),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${item.quantityKg.toStringAsFixed(1)} kg × NPR ${item.pricePerKg.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (item.farmerName != null)
                  Text('From: ${item.farmerName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Text('NPR ${item.subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double? amount,
      {String? fallback, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(
            amount != null ? 'NPR ${amount.toStringAsFixed(0)}' : (fallback ?? ''),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: bold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Cancel Order', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('orders')
          .update({'status': OrderStatus.cancelled.dbValue})
          .eq('id', orderId);
      _loadOrder();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e')),
      );
    }
  }
}
