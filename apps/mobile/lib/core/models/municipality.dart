import 'package:latlong2/latlong.dart';

/// A Nepal municipality (nagarpalika/gaunpalika) from the database.
class Municipality {
  final String id;
  final String nameEn;
  final String nameNe;
  final String district;
  final int province;
  final LatLng? center;

  const Municipality({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.district,
    required this.province,
    this.center,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    LatLng? center;
    final lat = json['center_lat'];
    final lng = json['center_lng'];
    if (lat != null && lng != null) {
      center = LatLng(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );
    }

    return Municipality(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameNe: json['name_ne'] as String,
      district: json['district'] as String,
      province: json['province'] as int,
      center: center,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_en': nameEn,
        'name_ne': nameNe,
        'district': district,
        'province': province,
        'center_lat': center?.latitude,
        'center_lng': center?.longitude,
      };

  /// Province names in English.
  static const Map<int, String> provinceNamesEn = {
    1: 'Koshi',
    2: 'Madhesh',
    3: 'Bagmati',
    4: 'Gandaki',
    5: 'Lumbini',
    6: 'Karnali',
    7: 'Sudurpashchim',
  };

  /// Province names in Nepali.
  static const Map<int, String> provinceNamesNe = {
    1: 'कोशी',
    2: 'मधेश',
    3: 'बागमती',
    4: 'गण्डकी',
    5: 'लुम्बिनी',
    6: 'कर्णाली',
    7: 'सुदूरपश्चिम',
  };

  String get provinceNameEn => provinceNamesEn[province] ?? 'Province $province';
  String get provinceNameNe => provinceNamesNe[province] ?? 'प्रदेश $province';

  @override
  String toString() => '$nameEn ($district, $provinceNameEn)';
}
