/// Business profile for B2B users (restaurants, hotels, canteens, etc.).
class BusinessProfile {
  final String id;
  final String userId;
  final String businessName;
  final String businessType; // restaurant, hotel, canteen, other
  final String? registrationNumber;
  final String address;
  final String? phone;
  final String? contactPerson;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessProfile({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessType,
    this.registrationNumber,
    required this.address,
    this.phone,
    this.contactPerson,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessName: json['business_name'] as String? ?? '',
      businessType: json['business_type'] as String? ?? 'other',
      registrationNumber: json['registration_number'] as String?,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String?,
      contactPerson: json['contact_person'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Human-readable label for the business type.
  String get businessTypeLabel {
    switch (businessType) {
      case 'restaurant':
        return 'Restaurant';
      case 'hotel':
        return 'Hotel';
      case 'canteen':
        return 'Canteen';
      default:
        return 'Other';
    }
  }

  bool get isVerified => verifiedAt != null;
}
