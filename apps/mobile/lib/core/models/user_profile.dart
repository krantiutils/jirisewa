import 'package:latlong2/latlong.dart';

import '../enums.dart';

class UserRoleEntry {
  final String id;
  final UserRole role;
  final String? farmName;
  final VehicleType? vehicleType;
  final double? vehicleCapacityKg;
  final bool verified;

  const UserRoleEntry({
    required this.id,
    required this.role,
    this.farmName,
    this.vehicleType,
    this.vehicleCapacityKg,
    this.verified = false,
  });

  factory UserRoleEntry.fromJson(Map<String, dynamic> json) {
    return UserRoleEntry(
      id: json['id'] as String,
      role: UserRole.fromString(json['role'] as String),
      farmName: json['farm_name'] as String?,
      vehicleType: json['vehicle_type'] != null
          ? VehicleType.fromString(json['vehicle_type'] as String)
          : null,
      vehicleCapacityKg: (json['vehicle_capacity_kg'] as num?)?.toDouble(),
      verified: json['verified'] as bool? ?? false,
    );
  }
}

class UserProfile {
  final String id;
  final String phone;
  final String name;
  final String? avatarUrl;
  final LatLng? location;
  final String? address;
  final String? municipality;
  final String lang;
  final double ratingAvg;
  final int ratingCount;
  final DateTime createdAt;
  final List<UserRoleEntry> roles;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    this.avatarUrl,
    this.location,
    this.address,
    this.municipality,
    this.lang = 'ne',
    this.ratingAvg = 0,
    this.ratingCount = 0,
    required this.createdAt,
    this.roles = const [],
  });

  bool hasRole(UserRole role) => roles.any((r) => r.role == role);

  Set<UserRole> get roleSet => roles.map((r) => r.role).toSet();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final locRaw = json['location'] as String?;
    LatLng? location;
    if (locRaw != null) {
      // PostGIS returns POINT(lng lat) or {lng, lat} via Supabase
      final match = RegExp(r'POINT\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(locRaw);
      if (match != null) {
        location = LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }
    }

    final rolesJson = json['user_roles'] as List<dynamic>?;

    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      location: location,
      address: json['address'] as String?,
      municipality: json['municipality'] as String?,
      lang: json['lang'] as String? ?? 'ne',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      roles: rolesJson?.map((r) => UserRoleEntry.fromJson(r as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
