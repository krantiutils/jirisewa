import 'package:latlong2/latlong.dart';

class ProduceListing {
  final String id;
  final String farmerId;
  final String? categoryId;
  final String nameEn;
  final String nameNe;
  final String? description;
  final double pricePerKg;
  final double availableQtyKg;
  final DateTime? freshnessDate;
  final LatLng? location;
  final List<String> photos;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? farmerName;
  final String? farmerPhone;
  final double? farmerRatingAvg;
  final String? categoryNameEn;
  final String? categoryNameNe;

  const ProduceListing({
    required this.id,
    required this.farmerId,
    this.categoryId,
    required this.nameEn,
    required this.nameNe,
    this.description,
    required this.pricePerKg,
    required this.availableQtyKg,
    this.freshnessDate,
    this.location,
    this.photos = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.farmerName,
    this.farmerPhone,
    this.farmerRatingAvg,
    this.categoryNameEn,
    this.categoryNameNe,
  });

  String name(String lang) => lang == 'ne' && nameNe.isNotEmpty ? nameNe : nameEn;

  String? categoryName(String lang) =>
      lang == 'ne' ? categoryNameNe : categoryNameEn;

  factory ProduceListing.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    final locRaw = json['location'] as String?;
    if (locRaw != null) {
      final match =
          RegExp(r'POINT\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(locRaw);
      if (match != null) {
        location = LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }
    }

    final photosRaw = json['photos'];
    List<String> photos = [];
    if (photosRaw is List) {
      photos = photosRaw.cast<String>();
    }

    // Handle joined farmer data
    final farmerData = json['farmer'] as Map<String, dynamic>?;
    final categoryData = json['category'] as Map<String, dynamic>?;

    return ProduceListing(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      categoryId: json['category_id'] as String?,
      nameEn: json['name_en'] as String? ?? '',
      nameNe: json['name_ne'] as String? ?? '',
      description: json['description'] as String?,
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      availableQtyKg: (json['available_qty_kg'] as num).toDouble(),
      freshnessDate: json['freshness_date'] != null
          ? DateTime.tryParse(json['freshness_date'] as String)
          : null,
      location: location,
      photos: photos,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      farmerName: farmerData?['name'] as String?,
      farmerPhone: farmerData?['phone'] as String?,
      farmerRatingAvg: (farmerData?['rating_avg'] as num?)?.toDouble(),
      categoryNameEn: categoryData?['name_en'] as String?,
      categoryNameNe: categoryData?['name_ne'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'farmer_id': farmerId,
      if (categoryId != null) 'category_id': categoryId,
      'name_en': nameEn,
      'name_ne': nameNe,
      if (description != null) 'description': description,
      'price_per_kg': pricePerKg,
      'available_qty_kg': availableQtyKg,
      if (freshnessDate != null)
        'freshness_date': freshnessDate!.toIso8601String().split('T').first,
      if (photos.isNotEmpty) 'photos': photos,
      'is_active': isActive,
    };
  }
}
