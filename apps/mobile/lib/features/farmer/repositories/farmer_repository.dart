import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FarmerRepository {
  final SupabaseClient _client;
  FarmerRepository(this._client);

  /// Fetch all produce categories ordered by sort_order.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final result = await _client
        .from('produce_categories')
        .select('id, name_en, name_ne, icon, sort_order')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(result);
  }

  /// Create a new produce listing.
  Future<Map<String, dynamic>> createListing({
    required String farmerId,
    required String categoryId,
    required String nameEn,
    required String nameNe,
    String? description,
    required double pricePerKg,
    required double availableQtyKg,
    String? freshnessDate,
    List<String>? photos,
    LatLng? location,
    String? municipalityId,
  }) async {
    final data = <String, dynamic>{
      'farmer_id': farmerId,
      'category_id': categoryId,
      'name_en': nameEn,
      'name_ne': nameNe,
      'price_per_kg': pricePerKg,
      'available_qty_kg': availableQtyKg,
      'is_active': true,
    };

    if (description != null && description.isNotEmpty) {
      data['description'] = description;
    }
    if (freshnessDate != null && freshnessDate.isNotEmpty) {
      data['freshness_date'] = freshnessDate;
    }
    if (photos != null && photos.isNotEmpty) {
      data['photos'] = photos;
    }
    if (location != null) {
      data['location'] =
          'POINT(${location.longitude} ${location.latitude})';
    }
    if (municipalityId != null && municipalityId.isNotEmpty) {
      data['municipality_id'] = municipalityId;
    }

    final result = await _client
        .from('produce_listings')
        .insert(data)
        .select()
        .single();
    return result;
  }

  /// Update an existing produce listing. Only updates non-null fields.
  Future<Map<String, dynamic>> updateListing(
    String listingId, {
    String? categoryId,
    String? nameEn,
    String? nameNe,
    String? description,
    double? pricePerKg,
    double? availableQtyKg,
    String? freshnessDate,
    List<String>? photos,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};

    if (categoryId != null) data['category_id'] = categoryId;
    if (nameEn != null) data['name_en'] = nameEn;
    if (nameNe != null) data['name_ne'] = nameNe;
    if (description != null) data['description'] = description;
    if (pricePerKg != null) data['price_per_kg'] = pricePerKg;
    if (availableQtyKg != null) data['available_qty_kg'] = availableQtyKg;
    if (freshnessDate != null) data['freshness_date'] = freshnessDate;
    if (photos != null) data['photos'] = photos;
    if (isActive != null) data['is_active'] = isActive;

    final result = await _client
        .from('produce_listings')
        .update(data)
        .eq('id', listingId)
        .select()
        .single();
    return result;
  }

  /// Get a single listing by ID (for editing).
  Future<Map<String, dynamic>?> getListing(String listingId) async {
    final result = await _client
        .from('produce_listings')
        .select('*, produce_categories(name_en, name_ne, icon)')
        .eq('id', listingId)
        .maybeSingle();
    return result;
  }

  /// Upload a photo to Supabase Storage. Returns the public URL.
  Future<String> uploadPhoto(
    String userId,
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$userId/$fileName';

    await _client.storage.from('produce-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: false,
          ),
        );

    final publicUrl =
        _client.storage.from('produce-photos').getPublicUrl(path);
    return publicUrl;
  }

  /// Toggle listing active status (soft delete).
  Future<void> toggleActive(String listingId, bool isActive) async {
    await _client
        .from('produce_listings')
        .update({'is_active': isActive})
        .eq('id', listingId);
  }
}
