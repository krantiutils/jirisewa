import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jirisewa_mobile/features/farmer/providers/farmer_orders_provider.dart';
import 'package:jirisewa_mobile/features/farmer/repositories/farmer_orders_repository.dart';

/// Farmer orders screen with Active / Completed tabs.
class FarmerOrdersScreen extends ConsumerWidget {
  const FarmerOrdersScreen({super.key});

  static const _activeStatuses = {
    'pending',
    'matched',
    'picked_up',
    'in_transit',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(farmerOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (orders) {
            final active = orders
                .where((o) => _activeStatuses.contains(o.status))
                .toList();
            final completed = orders
                .where((o) => !_activeStatuses.contains(o.status))
                .toList();

            return TabBarView(
              children: [
                _OrderListTab(
                  orders: active,
                  emptyMessage: 'No active orders',
                  onRefresh: () => ref.refresh(farmerOrdersProvider.future),
                ),
                _OrderListTab(
                  orders: completed,
                  emptyMessage: 'No completed orders',
                  onRefresh: () => ref.refresh(farmerOrdersProvider.future),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderListTab extends StatelessWidget {
  final List<FarmerOrder> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _OrderListTab({
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) => _OrderCard(order: orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FarmerOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, yyyy').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: subtotal + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rs. ${order.farmerSubtotal.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),

          // Consumer name
          if (order.consumerName != null)
            Text(
              'Customer: ${order.consumerName}',
              style: theme.textTheme.bodyMedium,
            ),

          // Rider name
          if (order.riderName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rider: ${order.riderName}',
              style: theme.textTheme.bodyMedium,
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Item list
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.listingName ?? 'Item'} (${item.quantityKg.toStringAsFixed(1)} kg)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      'Rs. ${item.subtotal.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 8),

          // Date
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;

    switch (status) {
      case 'pending':
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
      case 'matched':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
      case 'picked_up':
      case 'in_transit':
        bgColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
      case 'delivered':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
      case 'cancelled':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
