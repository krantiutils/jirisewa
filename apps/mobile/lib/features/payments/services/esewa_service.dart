import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deep link scheme for payment callbacks.
const String _deepLinkScheme = 'jirisewa';

/// eSewa ePay V2 service for initiating payments via browser redirect.
///
/// Generates HMAC-SHA256 signed form parameters and launches the eSewa
/// payment page in an external browser. Verification is handled server-side
/// via the `/api/esewa/success` callback.
class EsewaService {
  final String secretKey;
  final String productCode;
  final bool isProduction;

  EsewaService({
    required this.secretKey,
    required this.productCode,
    this.isProduction = false,
  });

  String get _baseUrl => isProduction
      ? 'https://epay.esewa.com.np/api/epay/main/v2/form'
      : 'https://rc-epay.esewa.com.np/api/epay/main/v2/form';

  /// Generate HMAC-SHA256 signature for eSewa ePay V2.
  ///
  /// The signed message format is:
  /// `total_amount=<value>,transaction_uuid=<value>,product_code=<value>`
  String generateSignature(
    double totalAmount,
    String transactionUuid,
    String productCode,
  ) {
    final message = 'total_amount=$totalAmount,'
        'transaction_uuid=$transactionUuid,'
        'product_code=$productCode';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(message));
    return base64.encode(digest.bytes);
  }

  /// Build the full set of form parameters for the eSewa payment page.
  ///
  /// These parameters are appended as query params to the gateway URL
  /// and opened in the user's browser.
  Map<String, String> buildFormParams({
    required String transactionUuid,
    required double amount,
    required double deliveryCharge,
    required double totalAmount,
    double taxAmount = 0,
    double serviceCharge = 0,
    String? successUrl,
    String? failureUrl,
    String? orderId,
  }) {
    final signature =
        generateSignature(totalAmount, transactionUuid, productCode);

    final effectiveSuccessUrl = successUrl ??
        '$_deepLinkScheme://payment/esewa/success'
            '${orderId != null ? '?orderId=$orderId' : ''}';
    final effectiveFailureUrl = failureUrl ??
        '$_deepLinkScheme://payment/esewa/failure'
            '${orderId != null ? '?orderId=$orderId' : ''}';

    return {
      'amount': amount.toString(),
      'tax_amount': taxAmount.toString(),
      'product_service_charge': serviceCharge.toString(),
      'product_delivery_charge': deliveryCharge.toString(),
      'total_amount': totalAmount.toString(),
      'transaction_uuid': transactionUuid,
      'product_code': productCode,
      'signed_field_names': 'total_amount,transaction_uuid,product_code',
      'signature': signature,
      'success_url': effectiveSuccessUrl,
      'failure_url': effectiveFailureUrl,
    };
  }

  /// Build the payment URL with all form parameters and launch in browser.
  ///
  /// Returns `true` if the browser was opened successfully.
  /// The [orderId] is included in deep-link callback URLs for the app to
  /// identify which order the payment result belongs to.
  Future<bool> initiatePayment({
    required String orderId,
    required String transactionUuid,
    required double amount,
    required double deliveryCharge,
    required double totalAmount,
    double taxAmount = 0,
    double serviceCharge = 0,
    String? successUrl,
    String? failureUrl,
  }) async {
    final params = buildFormParams(
      transactionUuid: transactionUuid,
      amount: amount,
      deliveryCharge: deliveryCharge,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      serviceCharge: serviceCharge,
      successUrl: successUrl,
      failureUrl: failureUrl,
      orderId: orderId,
    );

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
