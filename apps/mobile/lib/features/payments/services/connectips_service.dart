import 'package:url_launcher/url_launcher.dart';

/// Deep link scheme for payment callbacks.
const String _deepLinkScheme = 'jirisewa';

/// connectIPS e-Payment service.
///
/// Builds signed form parameters and launches the connectIPS payment gateway
/// in an external browser. Verification is handled server-side via the
/// `/api/connectips/success` callback.
///
/// Note: RSA-SHA256 signing requires the merchant's private key, which is
/// kept server-side for security. The mobile app delegates token generation
/// to the backend. The [buildFormParams] method accepts a pre-computed token.
/// For development/testing, pass `'STUB'` as the token value.
class ConnectIPSService {
  final String merchantId;
  final String appId;
  final String appName;
  final bool isProduction;

  ConnectIPSService({
    required this.merchantId,
    required this.appId,
    this.appName = 'JiriSewa',
    this.isProduction = false,
  });

  String get _gatewayUrl => isProduction
      ? 'https://connectips.com/connectipswebgw/loginpage'
      : 'https://uat.connectips.com/connectipswebgw/loginpage';

  /// Build form parameters for the connectIPS gateway.
  ///
  /// The [token] should be an RSA-SHA256 signature generated server-side.
  /// The signing message format is:
  /// `MERCHANTID=<val>,APPID=<val>,REFERENCEID=<val>,TXNAMT=<val>`
  ///
  /// For development, pass `'STUB'` as the token.
  Map<String, String> buildFormParams({
    required String txnId,
    required String referenceId,
    required int amountPaisa,
    required String token,
    String? orderId,
    String? successUrl,
    String? failureUrl,
    String remarks = 'JiriSewa Order',
    String particulars = 'JiriSewa Payment',
  }) {
    final txnDate = _formatDate(DateTime.now());

    final effectiveSuccessUrl = successUrl ??
        '$_deepLinkScheme://payment/success?gateway=connectips'
            '${orderId != null ? '&orderId=$orderId' : ''}';
    final effectiveFailureUrl = failureUrl ??
        '$_deepLinkScheme://payment/failure?gateway=connectips'
            '${orderId != null ? '&orderId=$orderId' : ''}';

    return {
      'MERCHANTID': merchantId,
      'APPID': appId,
      'APPNAME': appName,
      'TXNID': txnId,
      'TXNDATE': txnDate,
      'TXNCRNCY': 'NPR',
      'TXNAMT': amountPaisa.toString(),
      'REFERENCEID': referenceId,
      'REMARKS': remarks.length > 20 ? remarks.substring(0, 20) : remarks,
      'PARTICULARS': particulars,
      'TOKEN': token,
      'successUrl': effectiveSuccessUrl,
      'failureUrl': effectiveFailureUrl,
    };
  }

  /// Launch the connectIPS gateway in an external browser.
  ///
  /// [params] should be the result of [buildFormParams].
  /// Returns `true` if the browser was opened successfully.
  Future<bool> launchPayment(Map<String, String> params) async {
    final uri = Uri.parse(_gatewayUrl).replace(queryParameters: params);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Convenience method: build form params and launch in one call.
  ///
  /// Returns `true` if the browser was opened successfully.
  Future<bool> initiatePayment({
    required String orderId,
    required String txnId,
    required String referenceId,
    required int amountPaisa,
    required String token,
    String? successUrl,
    String? failureUrl,
    String remarks = 'JiriSewa Order',
  }) async {
    final params = buildFormParams(
      txnId: txnId,
      referenceId: referenceId,
      amountPaisa: amountPaisa,
      token: token,
      orderId: orderId,
      successUrl: successUrl,
      failureUrl: failureUrl,
      remarks: remarks,
      particulars: 'Order-${orderId.length > 13 ? orderId.substring(0, 13) : orderId}',
    );

    return launchPayment(params);
  }

  /// Format a [DateTime] as DD-MM-YYYY for the TXNDATE field.
  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }
}
