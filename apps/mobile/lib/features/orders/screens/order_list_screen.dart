import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  List<models.Order> _activeOrders = [];
  List<models.Order> _pastOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      // Fetch orders where user is consumer, rider, or farmer (via order_items)
      final data = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), rider:users!rider_id(name), order_items(*, listing:produce_listings(name_en, name_ne), farmer:users!farmer_id(name))')
          .or('consumer_id.eq.$userId,rider_id.eq.$userId')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final orders = (data as List)
          .map((j) => models.Order.fromJson(j as Map<String, dynamic>))
          .toList();

      setState(() {
        _activeOrders = orders.where((o) => o.status.isActive).toList();
        _pastOrders = orders.where((o) => !o.status.isActive).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Failed to load orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active (${_activeOrders.length})'),
            Tab(text: 'Past (${_pastOrders.length})'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderList(_activeOrders, empty: 'No active orders'),
                  _buildOrderList(_pastOrders, empty: 'No past orders'),
                ],
              ),
      ),
    );
  }

  Widget _buildOrderList(List<models.Order> orders, {required String empty}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(empty, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(models.Order order) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final itemNames = order.items.map((i) => i.listingName('en')).join(', ');

    return Card(
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ));
          _loadOrders();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.id.substring(0, 8)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  _statusBadge(order.status),
                ],
              ),
              const SizedBox(height: 8),
              if (itemNames.isNotEmpty)
                Text(
                  itemNames,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(order.createdAt.toLocal()),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Text(
                    'NPR ${order.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = AppColors.accent;
      case OrderStatus.matched:
        color = AppColors.primary;
      case OrderStatus.pickedUp:
      case OrderStatus.inTransit:
        color = AppColors.secondary;
      case OrderStatus.delivered:
        color = const Color(0xFF059669);
      case OrderStatus.cancelled:
        color = AppColors.error;
      case OrderStatus.disputed:
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
