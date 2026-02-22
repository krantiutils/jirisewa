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
  ///
  /// For clearable optional fields (description, freshnessDate), pass an
  /// empty string to explicitly set them to null in the database. Pass null
  /// to leave them unchanged.
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
    if (description != null) {
      // Empty string means "clear the field" → store as null
      data['description'] = description.isEmpty ? null : description;
    }
    if (pricePerKg != null) data['price_per_kg'] = pricePerKg;
    if (availableQtyKg != null) data['available_qty_kg'] = availableQtyKg;
    if (freshnessDate != null) {
      data['freshness_date'] = freshnessDate.isEmpty ? null : freshnessDate;
    }
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

  /// Fetch analytics data via Supabase RPC functions.
  Future<Map<String, dynamic>> getAnalytics(String farmerId,
      {int days = 30}) async {
    final results = await Future.wait<dynamic>([
      _client.rpc('farmer_sales_by_category',
          params: {'p_farmer_id': farmerId, 'p_days': days}),
      _client.rpc('farmer_revenue_trend',
          params: {'p_farmer_id': farmerId, 'p_days': days}),
      _client.rpc('farmer_top_products',
          params: {'p_farmer_id': farmerId, 'p_days': days, 'p_limit': 10}),
      _client
          .rpc('farmer_price_benchmarks', params: {'p_farmer_id': farmerId}),
      _client.rpc('farmer_fulfillment_rate',
          params: {'p_farmer_id': farmerId, 'p_days': days}),
      _client
          .rpc('farmer_rating_distribution', params: {'p_farmer_id': farmerId}),
      _client
          .from('users')
          .select('rating_avg, rating_count')
          .eq('id', farmerId)
          .single(),
    ]);

    return {
      'salesByCategory': results[0] as List,
      'revenueTrend': results[1] as List,
      'topProducts': results[2] as List,
      'priceBenchmarks': results[3] as List,
      'fulfillment':
          (results[4] as List).isNotEmpty ? results[4][0] : <String, dynamic>{},
      'ratingDistribution': results[5] as List,
      'ratingAvg': (results[6] as Map<String, dynamic>)['rating_avg'],
      'ratingCount': (results[6] as Map<String, dynamic>)['rating_count'],
    };
  }

  /// Get current verification status for the farmer.
  Future<Map<String, dynamic>?> getVerificationStatus(String farmerId) async {
    final role = await _client
        .from('user_roles')
        .select('id, verification_status')
        .eq('user_id', farmerId)
        .eq('role', 'farmer')
        .maybeSingle();

    if (role == null) return null;

    final doc = await _client
        .from('verification_documents')
        .select()
        .eq('user_role_id', role['id'] as String)
        .maybeSingle();

    return {
      'roleId': role['id'],
      'verificationStatus': role['verification_status'],
      'document': doc,
    };
  }

  /// Upload a verification document photo.
  Future<String> uploadVerificationDoc(
    String userId,
    Uint8List bytes,
    String docType, {
    String extension = 'jpg',
  }) async {
    final path =
        '$userId/$docType/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('verification-docs').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
    return _client.storage.from('verification-docs').getPublicUrl(path);
  }

  /// Submit verification documents.
  Future<void> submitVerification(
    String roleId, {
    required String citizenshipPhotoUrl,
    required String farmPhotoUrl,
    String? municipalityLetterUrl,
  }) async {
    await _client.from('verification_documents').upsert(
      {
        'user_role_id': roleId,
        'citizenship_photo_url': citizenshipPhotoUrl,
        'farm_photo_url': farmPhotoUrl,
        'municipality_letter_url': municipalityLetterUrl,
      },
      onConflict: 'user_role_id',
    );

    // Update status to pending
    await _client
        .from('user_roles')
        .update({'verification_status': 'pending'}).eq('id', roleId);
  }
}
