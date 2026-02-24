import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/trips/providers/trips_provider.dart';

/// Aggregated data for the trip detail screen.
class TripDetailData {
  final Map<String, dynamic> trip;
  final List<Map<String, dynamic>> stops;
  final List<Map<String, dynamic>> orders;

  const TripDetailData({
    required this.trip,
    this.stops = const [],
    this.orders = const [],
  });
}

/// Fetches a single trip with its stops and matched orders in parallel.
final tripDetailProvider =
    FutureProvider.autoDispose.family<TripDetailData, String>(
  (ref, tripId) async {
    final repo = ref.watch(tripRepositoryProvider);

    final results = await Future.wait([
      repo.getTrip(tripId),
      repo.listTripStops(tripId),
      repo.listOrdersByTrip(tripId),
    ]);

    final trip = results[0] as Map<String, dynamic>?;
    if (trip == null) {
      throw Exception('Trip not found');
    }

    final stops = results[1] as List<Map<String, dynamic>>;
    final orders = results[2] as List<Map<String, dynamic>>;

    return TripDetailData(trip: trip, stops: stops, orders: orders);
  },
);
