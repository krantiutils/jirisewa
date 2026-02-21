import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/orders/providers/orders_provider.dart';

/// Orders list screen — shows orders based on active role.
/// Consumer: orders they placed. Rider: orders assigned to them.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersListProvider);

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
              child: ordersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load orders: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(ordersListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (data) => data.orders.isEmpty
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
                        onRefresh: () => ref.refresh(ordersListProvider.future),
                        child: ListView.builder(
                          itemCount: data.orders.length,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemBuilder: (ctx, i) =>
                              _orderTile(context, data.orders[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(BuildContext context, Map<String, dynamic> order) {
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
