import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

/// Orders list screen — shows orders based on active role.
/// Consumer: orders they placed. Rider: orders assigned to them.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final session = SessionProvider.of(context);
    final currentProfile = session.profile;
    if (!session.isAuthenticated || currentProfile == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = currentProfile.id;
      final role = session.activeRole;

      final query = _supabase
          .from('orders')
          .select('id, status, total_price, delivery_fee, delivery_address, created_at');

      List<dynamic> result;
      if (role == 'rider') {
        result = await query
            .eq('rider_id', userId)
            .order('created_at', ascending: false)
            .limit(20);
      } else {
        result = await query
            .eq('consumer_id', userId)
            .order('created_at', ascending: false)
            .limit(20);
      }

      setState(() {
        _orders = List<Map<String, dynamic>>.from(result);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'My Orders',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _loading
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
                              ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No orders yet',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadOrders,
                              child: ListView.builder(
                                itemCount: _orders.length,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemBuilder: (ctx, i) => _orderTile(_orders[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total_price'] as num?)?.toDouble() ?? 0;
    final fee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => context.go('${AppRoutes.orders}/${order['id']}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(status).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: _statusColor(status), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${(order['id'] as String).substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatStatus(status),
                      style: TextStyle(fontSize: 13, color: _statusColor(status), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${(total + fee).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
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
