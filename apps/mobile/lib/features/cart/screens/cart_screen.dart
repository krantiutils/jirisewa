import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/cart/models/cart.dart';
import 'package:jirisewa_mobile/features/cart/providers/cart_provider.dart';

/// Shopping cart screen showing items grouped by farmer, quantity controls,
/// per-farmer subtotals, grand total, and a checkout button.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cart.isEmpty ? 'Cart' : 'Cart (${cart.itemCount})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: cart.isEmpty ? _buildEmptyState(context) : _buildCartBody(context, ref, cart),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse fresh produce from local farmers',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.marketplace),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Browse Marketplace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBody(BuildContext context, WidgetRef ref, Cart cart) {
    final farmerGroups = cart.byFarmer;
    final farmerIds = farmerGroups.keys.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: farmerIds.length,
            itemBuilder: (context, index) {
              final farmerId = farmerIds[index];
              final items = farmerGroups[farmerId]!;
              return _FarmerSection(
                farmerId: farmerId,
                items: items,
              );
            },
          ),
        ),
        _CartSummaryBar(cart: cart),
      ],
    );
  }
}

/// A section of cart items from a single farmer with a header and subtotal.
class _FarmerSection extends ConsumerWidget {
  final String farmerId;
  final List<CartItem> items;

  const _FarmerSection({
    required this.farmerId,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerName = items.first.farmerName;
    final farmerSubtotal =
        items.fold<double>(0, (sum, item) => sum + item.subtotal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farmer header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(20),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.agriculture_outlined,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    farmerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          Container(
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _CartItemTile(item: items[i]),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                ],

                // Farmer subtotal
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Rs ${farmerSubtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single cart item row with photo, name, price, quantity controls, and remove.
class _CartItemTile extends ConsumerWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.photo != null
                  ? CachedNetworkImage(
                      imageUrl: item.photo!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.border,
                        child: const Icon(
                          Icons.eco,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.border,
                        child: const Icon(
                          Icons.eco,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.border,
                      child: const Icon(
                        Icons.eco,
                        color: AppColors.secondary,
                        size: 24,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Name, price, and controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${item.pricePerKg.toStringAsFixed(0)}/kg',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Quantity controls
                    _QuantityButton(
                      icon: Icons.remove,
                      onPressed: () {
                        final newQty = item.quantityKg - 0.5;
                        if (newQty <= 0) {
                          notifier.removeItem(item.listingId);
                        } else {
                          notifier.updateQuantity(item.listingId, newQty);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantityKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add,
                      onPressed: () {
                        notifier.updateQuantity(
                          item.listingId,
                          item.quantityKg + 0.5,
                        );
                      },
                    ),
                    const Spacer(),
                    // Item subtotal
                    Text(
                      'Rs ${item.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => notifier.removeItem(item.listingId),
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }
}

/// Small round button for quantity increment/decrement.
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Icon(icon, size: 18, color: AppColors.foreground),
        ),
      ),
    );
  }
}

/// Bottom bar showing grand total and checkout button.
class _CartSummaryBar extends StatelessWidget {
  final Cart cart;

  const _CartSummaryBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total weight
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total weight',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              Text(
                '${cart.totalKg.toStringAsFixed(1)} kg',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Rs ${cart.subtotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(AppRoutes.checkout),
              child: const Text('Proceed to Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
