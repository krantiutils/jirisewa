import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Deep link scheme for payment callbacks.
const String _deepLinkScheme = 'jirisewa';

// ---------------------------------------------------------------------------
// Response model
// ---------------------------------------------------------------------------

/// Response from the Khalti payment initiation API.
class KhaltiInitResponse {
  /// Unique payment identifier assigned by Khalti.
  final String pidx;

  /// URL to redirect the user to for completing payment.
  final String paymentUrl;

  /// ISO 8601 timestamp when the payment link expires.
  final String? expiresAt;

  const KhaltiInitResponse({
    required this.pidx,
    required this.paymentUrl,
    this.expiresAt,
  });

  factory KhaltiInitResponse.fromJson(Map<String, dynamic> json) {
    return KhaltiInitResponse(
      pidx: json['pidx'] as String,
      paymentUrl: json['payment_url'] as String,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Khalti ePayment API v2 service.
///
/// Initiates a payment via Khalti's server-to-server API, then opens the
/// returned `payment_url` in the user's browser. Verification is handled
/// server-side via the `/api/khalti/callback` route.
class KhaltiService {
  final String secretKey;
  final bool isProduction;

  /// Optional HTTP client for testing.
  final http.Client? httpClient;

  KhaltiService({
    required this.secretKey,
    this.isProduction = false,
    this.httpClient,
  });

  String get _initiateUrl => isProduction
      ? 'https://khalti.com/api/v2/epayment/initiate/'
      : 'https://dev.khalti.com/api/v2/epayment/initiate/';

  /// Call the Khalti initiation API and return the payment details.
  ///
  /// [amountPaisa] is the total amount in paisa (1 NPR = 100 paisa).
  /// Minimum is 1000 paisa (Rs. 10).
  ///
  /// Throws [KhaltiInitException] if the API call fails.
  Future<KhaltiInitResponse> initiatePayment({
    required String purchaseOrderId,
    required int amountPaisa,
    required String orderId,
    String orderName = 'JiriSewa Order',
    String? returnUrl,
    String websiteUrl = 'https://khetbata.xyz',
  }) async {
    final effectiveReturnUrl = returnUrl ??
        '$_deepLinkScheme://payment/success?gateway=khalti&orderId=$orderId';

    final client = httpClient ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse(_initiateUrl),
        headers: {
          'Authorization': 'Key $secretKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'return_url': effectiveReturnUrl,
          'website_url': websiteUrl,
          'amount': amountPaisa,
          'purchase_order_id': purchaseOrderId,
          'purchase_order_name': orderName,
        }),
      );

      if (response.statusCode != 200) {
        throw KhaltiInitException(
          'Khalti initiation failed (${response.statusCode}): ${response.body}',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return KhaltiInitResponse.fromJson(data);
    } finally {
      // Only close if we created the client internally.
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Open the Khalti payment URL in an external browser.
  ///
  /// Returns `true` if the browser was opened successfully.
  Future<bool> launchPayment(String paymentUrl) async {
    return launchUrl(
      Uri.parse(paymentUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Convenience method: initiate payment and immediately launch the
  /// payment URL in the browser.
  ///
  /// Returns the [KhaltiInitResponse] so the caller can track the `pidx`.
  Future<KhaltiInitResponse> initiateAndLaunch({
    required String purchaseOrderId,
    required int amountPaisa,
    required String orderId,
    String orderName = 'JiriSewa Order',
    String? returnUrl,
    String websiteUrl = 'https://khetbata.xyz',
  }) async {
    final response = await initiatePayment(
      purchaseOrderId: purchaseOrderId,
      amountPaisa: amountPaisa,
      orderId: orderId,
      orderName: orderName,
      returnUrl: returnUrl,
      websiteUrl: websiteUrl,
    );

    await launchPayment(response.paymentUrl);
    return response;
  }
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Exception thrown when Khalti payment initiation fails.
class KhaltiInitException implements Exception {
  final String message;
  const KhaltiInitException(this.message);

  @override
  String toString() => 'KhaltiInitException: $message';
}
