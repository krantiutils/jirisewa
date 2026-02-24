/// A saved delivery address for a user.
class SavedAddress {
  final String id;
  final String label;
  final String addressText;
  final double lat;
  final double lng;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressText,
    required this.lat,
    required this.lng,
    this.isDefault = false,
  });

  /// Parse a row from the `user_addresses` table.
  ///
  /// Location is stored as PostGIS geography and returned as WKT
  /// `POINT(lng lat)`. Explicit `lat`/`lng` keys override the WKT value when
  /// present (e.g. from a join or RPC).
  factory SavedAddress.fromMap(Map<String, dynamic> map) {
    double lat = 0;
    double lng = 0;

    // Try to parse WKT location first.
    final location = map['location'];
    if (location is String) {
      final wkt = RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)');
      final match = wkt.firstMatch(location);
      if (match != null) {
        lng = double.tryParse(match.group(1)!) ?? 0;
        lat = double.tryParse(match.group(2)!) ?? 0;
      }
    }

    // Explicit lat/lng override WKT.
    if (map['lng'] != null) lng = (map['lng'] as num).toDouble();
    if (map['lat'] != null) lat = (map['lat'] as num).toDouble();

    return SavedAddress(
      id: map['id'] as String,
      label: (map['label'] as String?) ?? '',
      addressText: (map['address_text'] as String?) ?? '',
      lat: lat,
      lng: lng,
      isDefault: (map['is_default'] as bool?) ?? false,
    );
  }

  SavedAddress copyWith({
    String? label,
    String? addressText,
    double? lat,
    double? lng,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id,
      label: label ?? this.label,
      addressText: addressText ?? this.addressText,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
