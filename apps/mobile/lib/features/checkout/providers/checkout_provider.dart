import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/features/checkout/providers/delivery_fee_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CheckoutState {
  final int currentStep;
  final LatLng? deliveryLocation;
  final String deliveryAddress;
  final String? paymentMethod; // 'cash', 'esewa', 'khalti', 'connectips'
  final DeliveryFeeEstimate? feeEstimate;
  final bool isPlacingOrder;
  final String? error;

  const CheckoutState({
    this.currentStep = 0,
    this.deliveryLocation,
    this.deliveryAddress = '',
    this.paymentMethod,
    this.feeEstimate,
    this.isPlacingOrder = false,
    this.error,
  });

  CheckoutState copyWith({
    int? currentStep,
    LatLng? deliveryLocation,
    String? deliveryAddress,
    String? paymentMethod,
    DeliveryFeeEstimate? feeEstimate,
    bool? isPlacingOrder,
    String? error,
  }) {
    return CheckoutState(
      currentStep: currentStep ?? this.currentStep,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      feeEstimate: feeEstimate ?? this.feeEstimate,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      error: error,
    );
  }

  /// Whether the current step's requirements are satisfied.
  bool get canProceed {
    switch (currentStep) {
      case 0:
        return deliveryLocation != null;
      case 1:
        return paymentMethod != null;
      case 2:
        return feeEstimate != null;
      default:
        return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final checkoutProvider =
    NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void setLocation(LatLng location, String address) {
    state = state.copyWith(
      deliveryLocation: location,
      deliveryAddress: address,
    );
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setFeeEstimate(DeliveryFeeEstimate estimate) {
    state = state.copyWith(feeEstimate: estimate);
  }

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1, error: null);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1, error: null);
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 2) {
      state = state.copyWith(currentStep: step, error: null);
    }
  }

  /// Stub for placing an order. Full implementation in Task 1.4.
  Future<void> placeOrder() async {
    state = state.copyWith(isPlacingOrder: true, error: null);

    // Simulate a brief delay so the UI spinner shows.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Stub: real implementation will call the server action.
    state = state.copyWith(isPlacingOrder: false);
  }

  /// Reset the checkout state (e.g. after navigating away).
  void reset() {
    state = const CheckoutState();
  }
}
