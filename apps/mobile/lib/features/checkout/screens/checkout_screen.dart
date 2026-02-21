import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/cart/providers/cart_provider.dart';
import 'package:jirisewa_mobile/features/checkout/providers/checkout_provider.dart';
import 'package:jirisewa_mobile/features/checkout/providers/delivery_fee_provider.dart';
import 'package:jirisewa_mobile/features/map/widgets/location_picker.dart';

// ---------------------------------------------------------------------------
// Step labels for the progress indicator
// ---------------------------------------------------------------------------
const _stepLabels = ['Location', 'Payment', 'Review'];

// ---------------------------------------------------------------------------
// Payment method definitions
// ---------------------------------------------------------------------------
class _PaymentOption {
  final String key;
  final String label;
  final IconData icon;

  const _PaymentOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const _paymentOptions = [
  _PaymentOption(key: 'cash', label: 'Cash on Delivery', icon: Icons.money),
  _PaymentOption(
      key: 'esewa',
      label: 'eSewa',
      icon: Icons.account_balance_wallet),
  _PaymentOption(key: 'khalti', label: 'Khalti', icon: Icons.payment),
  _PaymentOption(
      key: 'connectips',
      label: 'connectIPS',
      icon: Icons.account_balance),
];

// ---------------------------------------------------------------------------
// CheckoutScreen
// ---------------------------------------------------------------------------

/// Multi-step checkout flow:
/// 0 - Delivery location picker
/// 1 - Payment method selection
/// 2 - Review & place order
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void deactivate() {
    // Reset checkout state when user leaves the screen.
    ref.read(checkoutProvider.notifier).reset();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(checkoutProvider);
    final cart = ref.watch(cartProvider);

    // Guard: redirect to cart if it's empty.
    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.remove_shopping_cart_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Your cart is empty',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.marketplace),
                child: const Text('Browse Marketplace'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: checkout.currentStep),
          const Divider(height: 1),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (checkout.currentStep) {
                0 => _LocationStep(key: const ValueKey(0)),
                1 => _PaymentStep(key: const ValueKey(1)),
                2 => _ReviewStep(key: const ValueKey(2)),
                _ => const SizedBox.shrink(),
              },
            ),
          ),

          // Bottom navigation buttons
          _BottomBar(
            currentStep: checkout.currentStep,
            canProceed: checkout.canProceed,
            isPlacingOrder: checkout.isPlacingOrder,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step Indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepBefore = index ~/ 2;
            final completed = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: completed ? AppColors.primary : AppColors.border,
              ),
            );
          }

          final step = index ~/ 2;
          final isActive = step == currentStep;
          final isCompleted = step < currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.primary
                      : isActive
                          ? AppColors.primary
                          : AppColors.muted,
                  border: Border.all(
                    color: isCompleted || isActive
                        ? AppColors.primary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : Colors.grey[500],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepLabels[step],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive || isCompleted
                      ? AppColors.primary
                      : Colors.grey[500],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 0: Delivery Location
// ---------------------------------------------------------------------------

class _LocationStep extends ConsumerWidget {
  const _LocationStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap on the map to set your delivery address',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LocationPickerWidget(
                initialLocation: checkout.deliveryLocation,
                onLocationSelected: (LatLng location, String address) {
                  ref
                      .read(checkoutProvider.notifier)
                      .setLocation(location, address);
                },
              ),
            ),
          ),
          if (checkout.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checkout.deliveryAddress,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Payment Method
// ---------------------------------------------------------------------------

class _PaymentStep extends ConsumerWidget {
  const _PaymentStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(checkoutProvider).paymentMethod;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how you want to pay',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _paymentOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = _paymentOptions[index];
                final isSelected = selected == option.key;

                return Material(
                  color: isSelected
                      ? AppColors.primary.withAlpha(15)
                      : AppColors.muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => ref
                        .read(checkoutProvider.notifier)
                        .setPaymentMethod(option.key),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.foreground,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Review Order
// ---------------------------------------------------------------------------

class _ReviewStep extends ConsumerStatefulWidget {
  const _ReviewStep({super.key});

  @override
  ConsumerState<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<_ReviewStep> {
  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(checkoutProvider);
    final cart = ref.watch(cartProvider);

    // Compute fee when we land on this step.
    final feeParams = checkout.deliveryLocation != null
        ? DeliveryFeeParams(
            deliveryLocation: checkout.deliveryLocation!,
            weightKg: cart.totalKg,
          )
        : null;

    final feeAsync =
        feeParams != null ? ref.watch(deliveryFeeProvider(feeParams)) : null;

    // Propagate fee estimate to checkout state via ref.listen (not in build).
    if (feeParams != null) {
      ref.listen(deliveryFeeProvider(feeParams), (prev, next) {
        final estimate = next.valueOrNull;
        if (estimate != null) {
          ref.read(checkoutProvider.notifier).setFeeEstimate(estimate);
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),

          // -- Cart Summary --
          _SectionCard(
            title: 'Items',
            icon: Icons.shopping_bag_outlined,
            child: Column(
              children: [
                _DetailRow(
                    label: 'Items', value: '${cart.itemCount} products'),
                _DetailRow(
                    label: 'Total weight',
                    value: '${cart.totalKg.toStringAsFixed(1)} kg'),
                _DetailRow(
                  label: 'Subtotal',
                  value: 'Rs ${cart.subtotal.toStringAsFixed(0)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // -- Delivery Fee Breakdown --
          _SectionCard(
            title: 'Delivery Fee',
            icon: Icons.local_shipping_outlined,
            child: feeAsync == null
                ? const Text('No delivery location set')
                : feeAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (e, _) => Text(
                      'Could not estimate fee. Using default.',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                    data: (estimate) => Column(
                      children: [
                        _DetailRow(
                          label: 'Distance',
                          value:
                              '${estimate.distanceKm.toStringAsFixed(1)} km',
                        ),
                        _DetailRow(
                          label: 'Base fee',
                          value:
                              'Rs ${estimate.baseFee.toStringAsFixed(0)}',
                        ),
                        _DetailRow(
                          label: 'Distance fee',
                          value:
                              'Rs ${estimate.distanceFee.toStringAsFixed(0)}',
                        ),
                        _DetailRow(
                          label: 'Weight fee',
                          value:
                              'Rs ${estimate.weightFee.toStringAsFixed(0)}',
                        ),
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Delivery fee',
                          value:
                              'Rs ${estimate.totalFee.toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // -- Delivery Address --
          _SectionCard(
            title: 'Delivery Address',
            icon: Icons.location_on_outlined,
            child: Text(
              checkout.deliveryAddress.isNotEmpty
                  ? checkout.deliveryAddress
                  : 'Not set',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),

          // -- Payment Method --
          _SectionCard(
            title: 'Payment Method',
            icon: Icons.payment_outlined,
            child: Text(
              _paymentLabel(checkout.paymentMethod),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),

          // -- Grand Total --
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withAlpha(50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Rs ${_grandTotal(cart.subtotal, checkout.feeEstimate).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          if (checkout.error != null) ...[
            const SizedBox(height: 12),
            Text(
              checkout.error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  double _grandTotal(double subtotal, DeliveryFeeEstimate? fee) {
    return subtotal + (fee?.totalFee ?? 0);
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Cash on Delivery';
      case 'esewa':
        return 'eSewa';
      case 'khalti':
        return 'Khalti';
      case 'connectips':
        return 'connectIPS';
      default:
        return 'Not selected';
    }
  }
}

// ---------------------------------------------------------------------------
// Shared UI helpers
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.foreground : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation bar
// ---------------------------------------------------------------------------

class _BottomBar extends ConsumerWidget {
  final int currentStep;
  final bool canProceed;
  final bool isPlacingOrder;

  const _BottomBar({
    required this.currentStep,
    required this.canProceed,
    required this.isPlacingOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReview = currentStep == 2;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Back button (hidden on first step)
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isPlacingOrder
                    ? null
                    : () =>
                        ref.read(checkoutProvider.notifier).previousStep(),
                child: const Text('Back'),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),

          // Next / Place Order button
          Expanded(
            flex: currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: canProceed && !isPlacingOrder
                  ? () => _onProceed(context, ref, isReview)
                  : null,
              child: isPlacingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isReview ? 'Place Order' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _onProceed(BuildContext context, WidgetRef ref, bool isReview) {
    if (isReview) {
      _handlePlaceOrder(context, ref);
    } else {
      ref.read(checkoutProvider.notifier).nextStep();
    }
  }

  Future<void> _handlePlaceOrder(BuildContext context, WidgetRef ref) async {
    await ref.read(checkoutProvider.notifier).placeOrder();

    if (!context.mounted) return;

    // Stub: show message and navigate to orders list (Task 1.4 will implement).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order placement coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Clear cart and navigate to orders.
    ref.read(cartProvider.notifier).clear();
    ref.read(checkoutProvider.notifier).reset();
    context.go(AppRoutes.orders);
  }
}
