/// User profile data from the `users` table.
class UserProfile {
  final String id;
  final String phone;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? address;
  final String? municipality;
  final String lang;
  final double ratingAvg;
  final int ratingCount;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.address,
    this.municipality,
    this.lang = 'ne',
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      phone: map['phone'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      avatarUrl: map['avatar_url'] as String?,
      address: map['address'] as String?,
      municipality: map['municipality'] as String?,
      lang: (map['lang'] as String?) ?? 'ne',
      ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  UserProfile copyWith({
    String? name,
    String? role,
    String? avatarUrl,
    String? address,
    String? municipality,
    String? lang,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      municipality: municipality ?? this.municipality,
      lang: lang ?? this.lang,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
    );
  }
}

/// Role-specific details from the `user_roles` table.
class UserRoleDetails {
  final String id;
  final String userId;
  final String role;
  final String? farmName;
  final String? vehicleType;
  final double? vehicleCapacityKg;
  final String? licensePhotoUrl;
  final bool verified;

  const UserRoleDetails({
    required this.id,
    required this.userId,
    required this.role,
    this.farmName,
    this.vehicleType,
    this.vehicleCapacityKg,
    this.licensePhotoUrl,
    this.verified = false,
  });

  factory UserRoleDetails.fromMap(Map<String, dynamic> map) {
    return UserRoleDetails(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      farmName: map['farm_name'] as String?,
      vehicleType: map['vehicle_type'] as String?,
      vehicleCapacityKg: (map['vehicle_capacity_kg'] as num?)?.toDouble(),
      licensePhotoUrl: map['license_photo_url'] as String?,
      verified: (map['verified'] as bool?) ?? false,
    );
  }
}
