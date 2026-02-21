import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/trips/repositories/trip_repository.dart';

/// Aggregated data for the trips screen.
class TripsData {
  final List<Map<String, dynamic>> trips;
  final Map<String, List<Map<String, dynamic>>> ordersByTripId;
  final Map<String, List<Map<String, dynamic>>> pingsByTripId;
  final List<Map<String, dynamic>> unassignedOrders;

  const TripsData({
    this.trips = const [],
    this.ordersByTripId = const {},
    this.pingsByTripId = const {},
    this.unassignedOrders = const [],
  });
}

/// Provider for the TripRepository, wired to the Supabase client.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(supabaseProvider));
});

/// Fetches trips, orders, and pings for the current rider and groups them.
final tripsDataProvider =
    FutureProvider.autoDispose<TripsData>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) {
    return const TripsData();
  }

  final riderId = profile.id;

  final results = await Future.wait([
    repo.listTrips(riderId),
    repo.listRiderOrders(riderId),
    repo.listPendingPings(riderId),
  ]);
  final trips = results[0];
  final orders = results[1];
  final pings = results[2];

  final byTrip = <String, List<Map<String, dynamic>>>{};
  final unassigned = <Map<String, dynamic>>[];

  for (final order in orders) {
    final tripId = order['rider_trip_id'] as String?;
    if (tripId == null) {
      unassigned.add(order);
      continue;
    }
    byTrip.putIfAbsent(tripId, () => []).add(order);
  }

  final pingsByTrip = <String, List<Map<String, dynamic>>>{};
  for (final ping in pings) {
    final tripId = ping['trip_id'] as String?;
    if (tripId == null) continue;
    pingsByTrip.putIfAbsent(tripId, () => []).add(ping);
  }

  return TripsData(
    trips: trips,
    ordersByTripId: byTrip,
    pingsByTripId: pingsByTrip,
    unassignedOrders: unassigned,
  );
});
