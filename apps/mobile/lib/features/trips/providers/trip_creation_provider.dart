import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/models/municipality.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/trips/providers/trips_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class TripCreationState {
  final int currentStep;

  // Step 1: Origin
  final Municipality? originMunicipality;
  final LatLng? originLocation;
  final String originAddress;

  // Step 2: Destination
  final Municipality? destinationMunicipality;
  final LatLng? destinationLocation;
  final String destinationAddress;

  // Step 3: Details
  final DateTime? departureAt;
  final double capacityKg;

  // Step 4: Review / submit
  final bool isCreating;
  final String? error;

  const TripCreationState({
    this.currentStep = 0,
    this.originMunicipality,
    this.originLocation,
    this.originAddress = '',
    this.destinationMunicipality,
    this.destinationLocation,
    this.destinationAddress = '',
    this.departureAt,
    this.capacityKg = 0,
    this.isCreating = false,
    this.error,
  });

  TripCreationState copyWith({
    int? currentStep,
    Municipality? originMunicipality,
    LatLng? originLocation,
    String? originAddress,
    Municipality? destinationMunicipality,
    LatLng? destinationLocation,
    String? destinationAddress,
    DateTime? departureAt,
    double? capacityKg,
    bool? isCreating,
    String? error,
  }) {
    return TripCreationState(
      currentStep: currentStep ?? this.currentStep,
      originMunicipality: originMunicipality ?? this.originMunicipality,
      originLocation: originLocation ?? this.originLocation,
      originAddress: originAddress ?? this.originAddress,
      destinationMunicipality:
          destinationMunicipality ?? this.destinationMunicipality,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      departureAt: departureAt ?? this.departureAt,
      capacityKg: capacityKg ?? this.capacityKg,
      isCreating: isCreating ?? this.isCreating,
      error: error,
    );
  }

  /// Whether the current step's requirements are satisfied.
  bool get canProceed {
    switch (currentStep) {
      case 0:
        return originLocation != null;
      case 1:
        return destinationLocation != null;
      case 2:
        return departureAt != null &&
            departureAt!.isAfter(DateTime.now()) &&
            capacityKg > 0;
      case 3:
        return true; // Review step — always ready to submit
      default:
        return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tripCreationProvider =
    NotifierProvider<TripCreationNotifier, TripCreationState>(
  TripCreationNotifier.new,
);

class TripCreationNotifier extends Notifier<TripCreationState> {
  @override
  TripCreationState build() => const TripCreationState();

  // -- Step 1: Origin -------------------------------------------------------

  void setOriginMunicipality(Municipality? municipality) {
    state = state.copyWith(originMunicipality: municipality);
  }

  void setOriginLocation(LatLng location, String address) {
    state = state.copyWith(
      originLocation: location,
      originAddress: address,
    );
  }

  // -- Step 2: Destination --------------------------------------------------

  void setDestinationMunicipality(Municipality? municipality) {
    state = state.copyWith(destinationMunicipality: municipality);
  }

  void setDestinationLocation(LatLng location, String address) {
    state = state.copyWith(
      destinationLocation: location,
      destinationAddress: address,
    );
  }

  // -- Step 3: Details ------------------------------------------------------

  void setDepartureAt(DateTime dateTime) {
    state = state.copyWith(departureAt: dateTime);
  }

  void setCapacityKg(double kg) {
    state = state.copyWith(capacityKg: kg);
  }

  // -- Navigation -----------------------------------------------------------

  void nextStep() {
    if (state.currentStep < 3 && state.canProceed) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        error: null,
      );
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        error: null,
      );
    }
  }

  // -- Trip Creation --------------------------------------------------------

  /// Fetches OSRM route, creates trip via repository, invalidates trip list.
  Future<bool> createTrip() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) {
      state = state.copyWith(error: 'Not logged in');
      return false;
    }

    final origin = state.originLocation;
    final destination = state.destinationLocation;
    if (origin == null || destination == null) {
      state = state.copyWith(error: 'Origin and destination are required');
      return false;
    }

    if (state.departureAt == null || state.capacityKg <= 0) {
      state = state.copyWith(error: 'Departure time and capacity are required');
      return false;
    }

    state = state.copyWith(isCreating: true, error: null);

    try {
      final repo = ref.read(tripRepositoryProvider);

      // Fetch OSRM route (best effort — trip can still be created without it)
      final routeCoords = await repo.fetchOsrmRoute(origin, destination);

      // Build origin/destination names (prefer address, fallback to municipality)
      final originName = state.originAddress.isNotEmpty
          ? state.originAddress
          : state.originMunicipality?.nameEn ?? 'Origin';
      final destinationName = state.destinationAddress.isNotEmpty
          ? state.destinationAddress
          : state.destinationMunicipality?.nameEn ?? 'Destination';

      await repo.createTrip(
        riderId: profile.id,
        origin: origin,
        originName: originName,
        destination: destination,
        destinationName: destinationName,
        departureAt: state.departureAt!,
        availableCapacityKg: state.capacityKg,
        routeCoordinates: routeCoords,
        originMunicipalityId: state.originMunicipality?.id,
        destinationMunicipalityId: state.destinationMunicipality?.id,
      );

      // Invalidate the trips list so it refreshes.
      ref.invalidate(tripsDataProvider);

      state = state.copyWith(isCreating: false);
      return true;
    } catch (e) {
      debugPrint('createTrip failed: $e');
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create trip. Please try again.',
      );
      return false;
    }
  }

  /// Reset state (e.g. when navigating away).
  void reset() {
    state = const TripCreationState();
  }
}
