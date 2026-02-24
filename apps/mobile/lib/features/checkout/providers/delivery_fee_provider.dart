import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';

// ---------------------------------------------------------------------------
// Default delivery fee rates (hardcoded for MVP; later from delivery_rates table)
// ---------------------------------------------------------------------------
const double _baseFeeNpr = 50;
const double _perKmRateNpr = 15;
const double _perKgRateNpr = 5;
const double _regionMultiplier = 1.0;
const double _minFeeNpr = 50;
const double _maxFeeNpr = 500;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Parameters required to estimate the delivery fee.
class DeliveryFeeParams {
  final LatLng deliveryLocation;
  final double weightKg;

  const DeliveryFeeParams({
    required this.deliveryLocation,
    required this.weightKg,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryFeeParams &&
          other.deliveryLocation == deliveryLocation &&
          other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(deliveryLocation, weightKg);
}

/// Breakdown of the computed delivery fee.
class DeliveryFeeEstimate {
  final double baseFee;
  final double distanceFee;
  final double weightFee;
  final double totalFee;
  final double distanceKm;

  const DeliveryFeeEstimate({
    required this.baseFee,
    required this.distanceFee,
    required this.weightFee,
    required this.totalFee,
    required this.distanceKm,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Fetches OSRM driving distance and computes delivery fee.
///
/// Uses Jiri center as the representative farmer origin (simplified for MVP).
final deliveryFeeProvider =
    FutureProvider.autoDispose.family<DeliveryFeeEstimate, DeliveryFeeParams>(
  (ref, params) async {
    final distanceKm = await _fetchDrivingDistanceKm(
      origin: jiriCenter,
      destination: params.deliveryLocation,
    );

    final distanceFee = distanceKm * _perKmRateNpr;
    final weightFee = params.weightKg * _perKgRateNpr;
    final rawTotal = (_baseFeeNpr + distanceFee + weightFee) * _regionMultiplier;
    final clampedTotal = rawTotal.clamp(_minFeeNpr, _maxFeeNpr);

    return DeliveryFeeEstimate(
      baseFee: _baseFeeNpr,
      distanceFee: distanceFee,
      weightFee: weightFee,
      totalFee: clampedTotal,
      distanceKm: distanceKm,
    );
  },
);

// ---------------------------------------------------------------------------
// OSRM helper
// ---------------------------------------------------------------------------

/// Calls the OSRM route API and returns the driving distance in kilometres.
///
/// Falls back to Haversine straight-line distance if the API call fails.
Future<double> _fetchDrivingDistanceKm({
  required LatLng origin,
  required LatLng destination,
}) async {
  try {
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$osrmBaseUrl/route/v1/driving/$coords?overview=false');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] == 'Ok') {
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final distanceMeters =
              (routes[0] as Map<String, dynamic>)['distance'] as num;
          return distanceMeters.toDouble() / 1000.0;
        }
      }
    }
  } catch (_) {
    // Fall through to Haversine fallback.
  }

  // Haversine straight-line fallback
  const haversine = Distance();
  final meters = haversine.as(LengthUnit.Meter, origin, destination);
  return meters / 1000.0;
}
