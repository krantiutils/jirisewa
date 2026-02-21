import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/business/models/bulk_order.dart';
import 'package:jirisewa_mobile/features/business/providers/business_provider.dart';

/// Farmer screen to view and respond to bulk order items addressed to them.
class FarmerBulkOrdersScreen extends ConsumerWidget {
  const FarmerBulkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(farmerBulkOrdersProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Bulk Order Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load orders: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(farmerBulkOrdersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(farmerBulkOrdersProvider);
                await ref.read(farmerBulkOrdersProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No bulk order requests',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When businesses order your produce, they will appear here',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final farmerId = profile?.id;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(farmerBulkOrdersProvider);
              await ref.read(farmerBulkOrdersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: orders.length,
              itemBuilder: (context, index) => _FarmerOrderCard(
                order: orders[index],
                farmerId: farmerId ?? '',
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer Order Card — shows items relevant to the farmer
// ---------------------------------------------------------------------------

class _FarmerOrderCard extends ConsumerWidget {
  const _FarmerOrderCard({
    required this.order,
    required this.farmerId,
  });

  final BulkOrder order;
  final String farmerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter items belonging to this farmer
    final myItems =
        order.items.where((i) => i.farmerId == farmerId).toList();

    if (myItems.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _StatusChip(
                  status: order.status,
                  label: order.statusLabel,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.frequencyLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),

            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Note: ${order.notes}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // My items
            Text(
              'Your Items (${myItems.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            ...myItems.map(
              (item) => _FarmerItemRow(item: item, ref: ref),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer Item Row with quote/reject actions
// ---------------------------------------------------------------------------

class _FarmerItemRow extends StatelessWidget {
  const _FarmerItemRow({required this.item, required this.ref});
  final BulkOrderItem item;
  final WidgetRef ref;

  Color get _statusColor {
    switch (item.status) {
      case 'pending':
        return AppColors.accent;
      case 'quoted':
        return AppColors.primary;
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
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.listingNameEn ?? 'Unknown Produce',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
            const SizedBox(height: 6),

            // Quantity and price
            Row(
              children: [
                Text(
                  '${item.quantityKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  'at Rs ${item.pricePerKg.toStringAsFixed(0)}/kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  'Rs ${(item.quantityKg * item.pricePerKg).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            // Quoted price
            if (item.quotedPricePerKg != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Your quote: Rs ${item.quotedPricePerKg!.toStringAsFixed(0)}/kg',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],

            // Farmer notes
            if (item.farmerNotes != null && item.farmerNotes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Your note: ${item.farmerNotes}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],

            // Action buttons (only for pending items)
            if (item.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showRejectDialog(context, ref, item),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showQuoteDialog(context, ref, item),
                      icon: const Icon(Icons.local_offer, size: 16),
                      label: const Text('Quote'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuoteDialog(
    BuildContext context,
    WidgetRef ref,
    BulkOrderItem item,
  ) {
    final priceController = TextEditingController(
      text: item.pricePerKg.toStringAsFixed(0),
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quote Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.listingNameEn ?? 'Unknown Produce',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${item.quantityKg.toStringAsFixed(1)} kg requested',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price per kg (NPR)',
                  prefixText: 'Rs ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Best quality available',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid price'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();
                await _quoteItem(
                  context,
                  ref,
                  item,
                  price,
                  notesController.text.trim(),
                );
              },
              child: const Text('Submit Quote'),
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(
    BuildContext context,
    WidgetRef ref,
    BulkOrderItem item,
  ) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject "${item.listingNameEn ?? 'item'}"?',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Out of stock',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _rejectItem(
                  context,
                  ref,
                  item,
                  notesController.text.trim(),
                );
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _quoteItem(
    BuildContext context,
    WidgetRef ref,
    BulkOrderItem item,
    double price,
    String notes,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.quoteBulkOrderItem(
        item.id,
        profile.id,
        price,
        notes: notes.isNotEmpty ? notes : null,
      );

      ref.invalidate(farmerBulkOrdersProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Quote submitted!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to submit quote: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectItem(
    BuildContext context,
    WidgetRef ref,
    BulkOrderItem item,
    String notes,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.rejectBulkOrderItem(
        item.id,
        profile.id,
        notes: notes.isNotEmpty ? notes : null,
      );

      ref.invalidate(farmerBulkOrdersProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Item rejected'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Status Chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  Color get _color {
    switch (status) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
