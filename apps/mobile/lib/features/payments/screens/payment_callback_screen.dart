import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jirisewa_mobile/l10n/app_localizations.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';

/// Screen shown briefly during payment gateway callbacks (deep links).
///
/// Extracts the order ID from query parameters and redirects to the order
/// detail page, showing a loading indicator in the interim.
class PaymentCallbackScreen extends StatefulWidget {
  final String gateway;
  final String result; // 'success' or 'failure'
  final Map<String, String> queryParams;

  const PaymentCallbackScreen({
    super.key,
    required this.gateway,
    required this.result,
    required this.queryParams,
  });

  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends State<PaymentCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect after a brief delay to allow the widget tree to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallback();
    });
  }

  void _handleCallback() {
    // Extract order ID from various possible query param names used by
    // the different payment gateways.
    final orderId = widget.queryParams['order_id'] ??
        widget.queryParams['orderId'] ??
        widget.queryParams['purchase_order_id'] ??
        widget.queryParams['transaction_uuid'];

    if (orderId != null && orderId.isNotEmpty && mounted) {
      context.go('${AppRoutes.orders}/$orderId');
    } else if (mounted) {
      // If we can't determine the order, go to the orders list.
      context.go(AppRoutes.orders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuccess = widget.result == 'success';
    final message = isSuccess
        ? (l10n?.paymentSuccess ?? 'Payment successful!')
        : (l10n?.paymentFailed ?? 'Payment failed');

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              size: 48,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.paymentVerifying ?? 'Verifying payment...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
