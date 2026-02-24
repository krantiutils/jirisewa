import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/cart/providers/cart_provider.dart';

/// A shopping cart icon with a count badge overlay.
///
/// Badge is only visible when the cart has items. Tapping navigates to `/cart`.
/// Designed for use as an AppBar action or floating button.
class CartBadge extends ConsumerWidget {
  /// Icon size for the shopping cart icon.
  final double iconSize;

  /// Optional override for the icon color.
  final Color? iconColor;

  const CartBadge({
    super.key,
    this.iconSize = 24,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final count = cart.itemCount;

    return IconButton(
      onPressed: () => context.push(AppRoutes.cart),
      tooltip: 'Cart',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        child: Icon(
          Icons.shopping_cart_outlined,
          size: iconSize,
          color: iconColor ?? AppColors.foreground,
        ),
      ),
    );
  }
}
