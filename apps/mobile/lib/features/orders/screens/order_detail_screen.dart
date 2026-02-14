import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/theme.dart';

/// Order detail screen — accessed via deep link /orders/:id.
/// Shows order status, items, delivery info, and tracking.
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

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadOrder();
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

      setState(() {
        _order = order;
        _items = List<Map<String, dynamic>>.from(items);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load order: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      ElevatedButton(onPressed: _loadOrder, child: const Text('Retry')),
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
                        // Status badge
                        _statusBadge(_order!['status'] as String? ?? 'pending'),
                        const SizedBox(height: 24),

                        // Delivery info
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
                                  const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _order!['delivery_address'] as String? ?? 'No address',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.payments_outlined, size: 18, color: AppColors.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    (_order!['payment_method'] as String? ?? 'cash').toUpperCase(),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatPaymentStatus(_order!['payment_status'] as String? ?? 'pending'),
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Items
                        _sectionTitle('Items'),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          const Text('No items', style: TextStyle(color: Colors.grey))
                        else
                          ..._items.map(_itemTile),

                        const SizedBox(height: 16),

                        // Totals
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _totalRow('Produce', 'Rs ${_order!['total_price'] ?? 0}'),
                              const SizedBox(height: 4),
                              _totalRow('Delivery', 'Rs ${_order!['delivery_fee'] ?? 0}'),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Container(height: 2, color: AppColors.border),
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
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                    if (delivered)
                      _badge('Delivered', AppColors.secondary),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : null)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : null)),
      ],
    );
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
    ).join(' ');
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
}
