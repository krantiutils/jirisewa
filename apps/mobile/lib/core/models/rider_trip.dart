import 'package:latlong2/latlong.dart';

import '../enums.dart';

class RiderTrip {
  final String id;
  final String riderId;
  final LatLng origin;
  final String originName;
  final LatLng destination;
  final String destinationName;
  final List<LatLng>? routeCoordinates;
  final DateTime departureAt;
  final double availableCapacityKg;
  final double remainingCapacityKg;
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? riderName;
  final String? riderPhone;
  final double? riderRatingAvg;
  final int matchedOrderCount;

  const RiderTrip({
    required this.id,
    required this.riderId,
    required this.origin,
    required this.originName,
    required this.destination,
    required this.destinationName,
    this.routeCoordinates,
    required this.departureAt,
    required this.availableCapacityKg,
    required this.remainingCapacityKg,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.riderName,
    this.riderPhone,
    this.riderRatingAvg,
    this.matchedOrderCount = 0,
  });

  factory RiderTrip.fromJson(Map<String, dynamic> json) {
    LatLng parsePoint(String? raw) {
      if (raw == null) return LatLng(0, 0);
      final match =
          RegExp(r'POINT\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(raw);
      if (match != null) {
        return LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }
      return LatLng(0, 0);
    }

    final riderData = json['rider'] as Map<String, dynamic>?;

    return RiderTrip(
      id: json['id'] as String,
      riderId: json['rider_id'] as String,
      origin: parsePoint(json['origin'] as String?),
      originName: json['origin_name'] as String? ?? '',
      destination: parsePoint(json['destination'] as String?),
      destinationName: json['destination_name'] as String? ?? '',
      departureAt: DateTime.parse(json['departure_at'] as String),
      availableCapacityKg:
          (json['available_capacity_kg'] as num?)?.toDouble() ?? 0,
      remainingCapacityKg:
          (json['remaining_capacity_kg'] as num?)?.toDouble() ?? 0,
      status: TripStatus.fromDb(json['status'] as String? ?? 'scheduled'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      riderName: riderData?['name'] as String?,
      riderPhone: riderData?['phone'] as String?,
      riderRatingAvg: (riderData?['rating_avg'] as num?)?.toDouble(),
      matchedOrderCount: json['matched_order_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'rider_id': riderId,
      'origin': 'POINT(${origin.longitude} ${origin.latitude})',
      'origin_name': originName,
      'destination': 'POINT(${destination.longitude} ${destination.latitude})',
      'destination_name': destinationName,
      'departure_at': departureAt.toIso8601String(),
      'available_capacity_kg': availableCapacityKg,
      'remaining_capacity_kg': availableCapacityKg,
      'status': 'scheduled',
    };
  }
}
