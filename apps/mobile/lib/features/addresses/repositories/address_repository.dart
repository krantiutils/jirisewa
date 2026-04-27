import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/addresses/models/saved_address.dart';

class AddressRepository {
  final SupabaseClient _client;
  AddressRepository(this._client);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Fetch all saved addresses for [userId], default address first.
  Future<List<SavedAddress>> listAddresses(String userId) async {
    final rows = await _client
        .from('user_addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return rows
        .map((r) => SavedAddress.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Create a new saved address. If [isDefault] is true, existing defaults for
  /// this user are unset first.
  ///
  /// PostGIS `POINT(lng lat)` format: longitude first, latitude second.
  Future<void> createAddress({
    required String userId,
    required String label,
    required String addressText,
    required double lat,
    required double lng,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await _client
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);
    }

    await _client.from('user_addresses').insert({
      'user_id': userId,
      'label': label,
      'address_text': addressText,
      'location': 'POINT($lng $lat)',
      'is_default': isDefault,
    });
  }

  /// Update an existing address. Only non-null fields are applied.
  ///
  /// If [isDefault] is true, existing defaults for this user are unset first.
  /// Both [lat] and [lng] must be provided together to update location.
  Future<void> updateAddress({
    required String id,
    required String userId,
    String? label,
    String? addressText,
    double? lat,
    double? lng,
    bool? isDefault,
  }) async {
    final updates = <String, dynamic>{};

    if (label != null) updates['label'] = label;
    if (addressText != null) updates['address_text'] = addressText;
    if (isDefault != null) updates['is_default'] = isDefault;

    if (lat != null && lng != null) {
      updates['location'] = 'POINT($lng $lat)';
    }

    if (updates.isEmpty) return;

    if (isDefault == true) {
      await _client
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);
    }

    await _client
        .from('user_addresses')
        .update(updates)
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// Delete a saved address.
  Future<void> deleteAddress(String id, String userId) async {
    await _client
        .from('user_addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
