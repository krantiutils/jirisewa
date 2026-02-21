import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/business/models/bulk_order.dart';
import 'package:jirisewa_mobile/features/business/providers/business_provider.dart';

/// Detail screen for a single bulk order, showing items and action buttons.
class BulkOrderDetailScreen extends ConsumerWidget {
  const BulkOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(bulkOrderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load order: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(bulkOrderDetailProvider(orderId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (order) {
          if (order == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Order not found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bulkOrderDetailProvider(orderId));
              await ref.read(bulkOrderDetailProvider(orderId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Order info card
                _OrderInfoCard(order: order),
                const SizedBox(height: 16),

                // Items section
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (order.items.isEmpty)
                  Card(
                    elevation: 0,
                    color: AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No items in this order',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  ...order.items.map(
                    (item) => _ItemCard(item: item),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                _ActionButtons(
                  order: order,
                  onCancel: () => _cancelOrder(context, ref, order),
                  onAccept: () => _acceptOrder(context, ref, order),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelOrder(
    BuildContext context,
    WidgetRef ref,
    BulkOrder order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final bizProfile = await ref.read(businessProfileProvider.future);
      if (bizProfile == null) throw Exception('Business profile not found');

      final repo = ref.read(businessRepositoryProvider);
      await repo.cancelBulkOrder(order.id, bizProfile.id);

      ref.invalidate(bulkOrderDetailProvider(orderId));
      ref.invalidate(bulkOrdersProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order cancelled'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _acceptOrder(
    BuildContext context,
    WidgetRef ref,
    BulkOrder order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: const Text(
          'Accept this order with the quoted prices? The total will be recalculated based on farmer quotes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final bizProfile = await ref.read(businessProfileProvider.future);
      if (bizProfile == null) throw Exception('Business profile not found');

      final repo = ref.read(businessRepositoryProvider);
      await repo.acceptBulkOrder(order.id, bizProfile.id);

      ref.invalidate(bulkOrderDetailProvider(orderId));
      ref.invalidate(bulkOrdersProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order accepted!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to accept: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Order Info Card
// ---------------------------------------------------------------------------

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.order});
  final BulkOrder order;

  Color get _statusColor {
    switch (order.status) {
      case 'submitted':
        return AppColors.primary;
      case 'quoted':
        return AppColors.accent;
      case 'accepted':
      case 'fulfilled':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Row(
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _DetailRow(
              label: 'Delivery Address',
              value: order.deliveryAddress,
            ),
            _DetailRow(
              label: 'Frequency',
              value: order.frequencyLabel,
            ),
            _DetailRow(
              label: 'Total Amount',
              value: 'Rs ${order.totalAmount.toStringAsFixed(2)}',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),

            if (order.notes != null && order.notes!.isNotEmpty)
              _DetailRow(label: 'Notes', value: order.notes!),

            _DetailRow(
              label: 'Created',
              value: _formatDate(order.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item Card
// ---------------------------------------------------------------------------

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final BulkOrderItem item;

  Color get _statusColor {
    switch (item.status) {
      case 'pending':
        return Colors.grey;
      case 'quoted':
        return AppColors.accent;
      case 'accepted':
        return AppColors.secondary;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Produce name + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.listingNameEn ?? 'Unknown Produce',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (item.listingNameNe != null && item.listingNameNe!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.listingNameNe!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ),

            const SizedBox(height: 8),

            // Farmer
            if (item.farmerName != null)
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    item.farmerName!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),

            const SizedBox(height: 6),

            // Quantity and prices
            Row(
              children: [
                Text(
                  '${item.quantityKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rs ${item.pricePerKg.toStringAsFixed(0)}/kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (item.quotedPricePerKg != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Rs ${item.quotedPricePerKg!.toStringAsFixed(0)}/kg',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const Text(
                    ' (quoted)',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),

            // Farmer notes
            if (item.farmerNotes != null && item.farmerNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.farmerNotes!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.order,
    required this.onCancel,
    required this.onAccept,
  });

  final BulkOrder order;
  final VoidCallback onCancel;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    if (!order.isCancellable && !order.isAcceptable) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (order.isAcceptable) ...[
          ElevatedButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check),
            label: const Text('Accept Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (order.isCancellable)
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
      ],
    );
  }
}
