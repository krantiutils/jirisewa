import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/payments/services/connectips_service.dart';
import 'package:jirisewa_mobile/features/payments/services/esewa_service.dart';
import 'package:jirisewa_mobile/features/payments/services/khalti_service.dart';

// ---------------------------------------------------------------------------
// Individual gateway providers
// ---------------------------------------------------------------------------

/// Provides the configured [EsewaService] instance.
///
/// TODO: Read secretKey and productCode from environment / remote config.
final esewaServiceProvider = Provider<EsewaService>((ref) {
  return EsewaService(
    secretKey: const String.fromEnvironment(
      'ESEWA_SECRET_KEY',
      defaultValue: '', // Must be set via --dart-define
    ),
    productCode: const String.fromEnvironment(
      'ESEWA_PRODUCT_CODE',
      defaultValue: 'EPAYTEST',
    ),
    isProduction:
        const String.fromEnvironment('ESEWA_ENVIRONMENT') == 'production',
  );
});

/// Provides the configured [KhaltiService] instance.
///
/// TODO: Read secretKey from environment / remote config.
/// NOTE: Khalti initiation is called directly from the mobile client,
/// which exposes the secret key on the device. For production, route
/// Khalti initiation through a backend endpoint instead.
final khaltiServiceProvider = Provider<KhaltiService>((ref) {
  return KhaltiService(
    secretKey: const String.fromEnvironment(
      'KHALTI_SECRET_KEY',
      defaultValue: '', // Must be set via --dart-define
    ),
    isProduction:
        const String.fromEnvironment('KHALTI_ENVIRONMENT') == 'production',
  );
});

/// Provides the configured [ConnectIPSService] instance.
///
/// TODO: Read merchantId and appId from environment / remote config.
final connectipsServiceProvider = Provider<ConnectIPSService>((ref) {
  return ConnectIPSService(
    merchantId: const String.fromEnvironment(
      'CONNECTIPS_MERCHANT_ID',
      defaultValue: '',
    ),
    appId: const String.fromEnvironment(
      'CONNECTIPS_APP_ID',
      defaultValue: '',
    ),
    appName: const String.fromEnvironment(
      'CONNECTIPS_APP_NAME',
      defaultValue: 'JiriSewa',
    ),
    isProduction: const String.fromEnvironment('CONNECTIPS_ENVIRONMENT') ==
        'production',
  );
});

// ---------------------------------------------------------------------------
// Unified payment service
// ---------------------------------------------------------------------------

/// Provides the high-level [PaymentService] that dispatches to the correct
/// gateway based on the payment method.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(
    esewa: ref.watch(esewaServiceProvider),
    khalti: ref.watch(khaltiServiceProvider),
    connectips: ref.watch(connectipsServiceProvider),
  );
});

/// High-level payment service that dispatches to the correct payment
/// gateway based on the payment method string.
///
/// This service handles payment initiation only. Verification is performed
/// server-side when the gateway redirects back to the API callback routes.
class PaymentService {
  final EsewaService esewa;
  final KhaltiService khalti;
  final ConnectIPSService connectips;

  PaymentService({
    required this.esewa,
    required this.khalti,
    required this.connectips,
  });

  /// Initiate a payment using the appropriate gateway.
  ///
  /// [gateway] must be one of: `'esewa'`, `'khalti'`, `'connectips'`.
  /// [orderId] is the order being paid for.
  /// [paymentData] contains gateway-specific fields from [PlaceOrderResult].
  ///
  /// Returns `true` if the payment page was successfully launched.
  /// Throws on API errors (Khalti) or invalid gateway values.
  Future<bool> initiatePayment({
    required String gateway,
    required String orderId,
    required Map<String, dynamic> paymentData,
  }) async {
    switch (gateway) {
      case 'esewa':
        return _initiateEsewa(orderId, paymentData);
      case 'khalti':
        return _initiateKhalti(orderId, paymentData);
      case 'connectips':
        return _initiateConnectIPS(orderId, paymentData);
      default:
        debugPrint('PaymentService: unknown gateway "$gateway"');
        return false;
    }
  }

  Future<bool> _initiateEsewa(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final transactionUuid = data['transactionUuid'] as String;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final deliveryCharge = (data['deliveryCharge'] as num?)?.toDouble() ?? 0;
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ??
        (amount + deliveryCharge);

    return esewa.initiatePayment(
      orderId: orderId,
      transactionUuid: transactionUuid,
      amount: amount,
      deliveryCharge: deliveryCharge,
      totalAmount: totalAmount,
    );
  }

  Future<bool> _initiateKhalti(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final purchaseOrderId = data['purchaseOrderId'] as String;
    final amountPaisa = data['amountPaisa'] as int;

    final response = await khalti.initiateAndLaunch(
      purchaseOrderId: purchaseOrderId,
      amountPaisa: amountPaisa,
      orderId: orderId,
    );

    // The pidx can be stored locally if needed for status polling.
    debugPrint('PaymentService: Khalti pidx=${response.pidx}');
    return true;
  }

  Future<bool> _initiateConnectIPS(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    final txnId = data['txnId'] as String;
    final referenceId = data['referenceId'] as String;
    final amountPaisa = data['amountPaisa'] as int;

    // Token should ideally be fetched from the server.
    // For now, use a stub token for development.
    // TODO: Fetch RSA-SHA256 token from backend API endpoint.
    final token = data['token'] as String? ?? 'STUB';

    return connectips.initiatePayment(
      orderId: orderId,
      txnId: txnId,
      referenceId: referenceId,
      amountPaisa: amountPaisa,
      token: token,
    );
  }
}
