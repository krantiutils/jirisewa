import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/business/models/business_profile.dart';
import 'package:jirisewa_mobile/features/business/models/bulk_order.dart';

class BusinessRepository {
  final SupabaseClient _client;
  BusinessRepository(this._client);

  // ---------------------------------------------------------------------------
  // Business Profile
  // ---------------------------------------------------------------------------

  /// Get the business profile for the current user. Returns null if none exists.
  Future<BusinessProfile?> getBusinessProfile(String userId) async {
    final result = await _client
        .from('business_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) return null;
    return BusinessProfile.fromJson(Map<String, dynamic>.from(result));
  }

  /// Create a new business profile. Returns the created profile.
  Future<BusinessProfile> createBusinessProfile({
    required String userId,
    required String businessName,
    required String businessType,
    String? registrationNumber,
    required String address,
    String? phone,
    String? contactPerson,
  }) async {
    if (businessName.trim().isEmpty) {
      throw Exception('Business name is required');
    }
    if (address.trim().isEmpty) {
      throw Exception('Address is required');
    }
    const validTypes = {'restaurant', 'hotel', 'canteen', 'other'};
    if (!validTypes.contains(businessType)) {
      throw Exception('Invalid business type: $businessType');
    }

    final result = await _client
        .from('business_profiles')
        .insert({
          'user_id': userId,
          'business_name': businessName.trim(),
          'business_type': businessType,
          'registration_number':
              registrationNumber?.trim().isNotEmpty == true
                  ? registrationNumber!.trim()
                  : null,
          'address': address.trim(),
          'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
          'contact_person':
              contactPerson?.trim().isNotEmpty == true
                  ? contactPerson!.trim()
                  : null,
        })
        .select()
        .single();

    return BusinessProfile.fromJson(Map<String, dynamic>.from(result));
  }

  /// Update an existing business profile.
  Future<BusinessProfile> updateBusinessProfile({
    required String profileId,
    required String userId,
    String? businessName,
    String? businessType,
    String? registrationNumber,
    String? address,
    String? phone,
    String? contactPerson,
  }) async {
    final updates = <String, dynamic>{};

    if (businessName != null && businessName.trim().isNotEmpty) {
      updates['business_name'] = businessName.trim();
    }
    if (businessType != null) {
      const validTypes = {'restaurant', 'hotel', 'canteen', 'other'};
      if (!validTypes.contains(businessType)) {
        throw Exception('Invalid business type: $businessType');
      }
      updates['business_type'] = businessType;
    }
    if (registrationNumber != null) {
      updates['registration_number'] =
          registrationNumber.trim().isNotEmpty ? registrationNumber.trim() : null;
    }
    if (address != null && address.trim().isNotEmpty) {
      updates['address'] = address.trim();
    }
    if (phone != null) {
      updates['phone'] = phone.trim().isNotEmpty ? phone.trim() : null;
    }
    if (contactPerson != null) {
      updates['contact_person'] =
          contactPerson.trim().isNotEmpty ? contactPerson.trim() : null;
    }

    if (updates.isEmpty) {
      throw Exception('No fields to update');
    }

    final result = await _client
        .from('business_profiles')
        .update(updates)
        .eq('id', profileId)
        .eq('user_id', userId)
        .select()
        .single();

    return BusinessProfile.fromJson(Map<String, dynamic>.from(result));
  }

  // ---------------------------------------------------------------------------
  // Bulk Orders — Business side
  // ---------------------------------------------------------------------------

  /// List bulk orders for a business, optionally filtered by status.
  /// Returns orders with their items including listing and farmer details.
  Future<List<BulkOrder>> listBulkOrders(
    String businessId, {
    String? statusFilter,
  }) async {
    var filterQuery = _client
        .from('bulk_orders')
        .select('*')
        .eq('business_id', businessId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      filterQuery = filterQuery.eq('status', statusFilter);
    }

    final orders = await filterQuery.order('created_at', ascending: false);
    if (orders.isEmpty) return [];

    // Fetch items for all orders
    final orderIds = orders.map((o) => o['id'] as String).toList();
    final items = await _client
        .from('bulk_order_items')
        .select(
          '*, produce_listings(name_en, name_ne, photos), users(name, avatar_url)',
        )
        .inFilter('bulk_order_id', orderIds);

    // Group items by order ID
    final itemsByOrder = <String, List<BulkOrderItem>>{};
    for (final item in items) {
      final map = Map<String, dynamic>.from(item);
      final orderId = map['bulk_order_id'] as String;
      itemsByOrder.putIfAbsent(orderId, () => []);
      itemsByOrder[orderId]!.add(BulkOrderItem.fromJson(map));
    }

    return orders.map((o) {
      final map = Map<String, dynamic>.from(o);
      final id = map['id'] as String;
      return BulkOrder.fromJson(map, items: itemsByOrder[id] ?? []);
    }).toList();
  }

  /// Get a single bulk order with all details.
  Future<BulkOrder?> getBulkOrder(String orderId) async {
    final result = await _client
        .from('bulk_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (result == null) return null;

    // Fetch items with joins
    final items = await _client
        .from('bulk_order_items')
        .select(
          '*, produce_listings(name_en, name_ne, photos), users(name, avatar_url)',
        )
        .eq('bulk_order_id', orderId);

    final parsedItems = items
        .map((i) => BulkOrderItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();

    return BulkOrder.fromJson(
      Map<String, dynamic>.from(result),
      items: parsedItems,
    );
  }

  /// Create a new bulk order with items.
  /// Validates listings are active and uses server-side prices.
  Future<BulkOrder> createBulkOrder({
    required String businessId,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    required String deliveryFrequency,
    Map<String, String>? deliverySchedule,
    String? notes,
    required List<BulkOrderItemInput> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('At least one item is required');
    }
    if (deliveryAddress.trim().isEmpty) {
      throw Exception('Delivery address is required');
    }

    // Verify listings exist and are active, get server-side prices
    final listingIds = items.map((i) => i.listingId).toSet().toList();
    final listings = await _client
        .from('produce_listings')
        .select('id, price_per_kg, farmer_id, is_active')
        .inFilter('id', listingIds);

    final listingMap = <String, Map<String, dynamic>>{};
    for (final l in listings) {
      listingMap[l['id'] as String] = Map<String, dynamic>.from(l);
    }

    // Validate all listings
    for (final item in items) {
      final listing = listingMap[item.listingId];
      if (listing == null) {
        throw Exception('Listing ${item.listingId} not found');
      }
      if (!(listing['is_active'] as bool? ?? false)) {
        throw Exception('Listing ${item.listingId} is no longer active');
      }
    }

    // Calculate total from server prices
    double totalAmount = 0;
    for (final item in items) {
      final listing = listingMap[item.listingId]!;
      final serverPrice = (listing['price_per_kg'] as num).toDouble();
      totalAmount += item.quantityKg * serverPrice;
    }
    totalAmount = _round2(totalAmount);

    // Build delivery location if coordinates provided
    String? deliveryLoc;
    if (deliveryLat != null && deliveryLng != null) {
      deliveryLoc = 'POINT($deliveryLng $deliveryLat)';
    }

    // Insert order
    final orderResult = await _client
        .from('bulk_orders')
        .insert({
          'business_id': businessId,
          'status': 'submitted',
          'delivery_address': deliveryAddress.trim(),
          'delivery_location': deliveryLoc,
          'delivery_frequency': deliveryFrequency,
          'delivery_schedule': deliverySchedule,
          'total_amount': totalAmount,
          'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        })
        .select()
        .single();

    final orderId = orderResult['id'] as String;

    try {
      // Insert items using server-side prices
      final itemRows = items.map((item) {
        final listing = listingMap[item.listingId]!;
        final serverPrice = (listing['price_per_kg'] as num).toDouble();
        final farmerId = listing['farmer_id'] as String;
        return <String, dynamic>{
          'bulk_order_id': orderId,
          'produce_listing_id': item.listingId,
          'farmer_id': farmerId,
          'quantity_kg': item.quantityKg,
          'price_per_kg': serverPrice,
          'status': 'pending',
        };
      }).toList();

      await _client.from('bulk_order_items').insert(itemRows);

      return BulkOrder.fromJson(Map<String, dynamic>.from(orderResult));
    } catch (e) {
      // Clean up on failure
      await _client.from('bulk_order_items').delete().eq('bulk_order_id', orderId);
      await _client.from('bulk_orders').delete().eq('id', orderId);
      rethrow;
    }
  }

  /// Cancel a bulk order. Verifies ownership and cancellable status.
  Future<void> cancelBulkOrder(String orderId, String businessId) async {
    final order = await _client
        .from('bulk_orders')
        .select('id, business_id, status')
        .eq('id', orderId)
        .single();

    if (order['business_id'] != businessId) {
      throw Exception('Not authorized to cancel this order');
    }

    final status = order['status'] as String;
    if (status != 'draft' && status != 'submitted' && status != 'quoted') {
      throw Exception('Order cannot be cancelled in current status: $status');
    }

    // Cancel order and all pending items
    await _client
        .from('bulk_order_items')
        .update({'status': 'cancelled'})
        .eq('bulk_order_id', orderId)
        .eq('status', 'pending');

    await _client
        .from('bulk_orders')
        .update({'status': 'cancelled'})
        .eq('id', orderId);
  }

  /// Accept a quoted bulk order. Recalculates total from quoted prices.
  Future<void> acceptBulkOrder(String orderId, String businessId) async {
    final order = await _client
        .from('bulk_orders')
        .select('id, business_id, status')
        .eq('id', orderId)
        .single();

    if (order['business_id'] != businessId) {
      throw Exception('Not authorized to accept this order');
    }
    if (order['status'] != 'quoted') {
      throw Exception('Only quoted orders can be accepted');
    }

    // Fetch quoted items and recalculate total
    final items = await _client
        .from('bulk_order_items')
        .select('id, quantity_kg, quoted_price_per_kg, status')
        .eq('bulk_order_id', orderId)
        .eq('status', 'quoted');

    double newTotal = 0;
    for (final item in items) {
      final qty = (item['quantity_kg'] as num).toDouble();
      final quotedPrice = (item['quoted_price_per_kg'] as num?)?.toDouble();
      if (quotedPrice != null) {
        newTotal += qty * quotedPrice;
      }
    }
    newTotal = _round2(newTotal);

    // Accept all quoted items
    await _client
        .from('bulk_order_items')
        .update({'status': 'accepted'})
        .eq('bulk_order_id', orderId)
        .eq('status', 'quoted');

    // Update order
    await _client.from('bulk_orders').update({
      'status': 'accepted',
      'total_amount': newTotal,
    }).eq('id', orderId);
  }

  // ---------------------------------------------------------------------------
  // Bulk Orders — Farmer side
  // ---------------------------------------------------------------------------

  /// List bulk orders that contain items for this farmer.
  Future<List<BulkOrder>> listFarmerBulkOrders(String farmerId) async {
    // Find bulk order IDs that have items from this farmer
    final farmerItems = await _client
        .from('bulk_order_items')
        .select('bulk_order_id')
        .eq('farmer_id', farmerId);

    if (farmerItems.isEmpty) return [];

    final orderIds =
        farmerItems.map((i) => i['bulk_order_id'] as String).toSet().toList();

    // Fetch those orders
    final orders = await _client
        .from('bulk_orders')
        .select('*')
        .inFilter('id', orderIds)
        .order('created_at', ascending: false);

    if (orders.isEmpty) return [];

    // Fetch all items for these orders (with joins)
    final allItems = await _client
        .from('bulk_order_items')
        .select(
          '*, produce_listings(name_en, name_ne, photos), users(name, avatar_url)',
        )
        .inFilter('bulk_order_id', orderIds);

    // Group items by order
    final itemsByOrder = <String, List<BulkOrderItem>>{};
    for (final item in allItems) {
      final map = Map<String, dynamic>.from(item);
      final oid = map['bulk_order_id'] as String;
      itemsByOrder.putIfAbsent(oid, () => []);
      itemsByOrder[oid]!.add(BulkOrderItem.fromJson(map));
    }

    return orders.map((o) {
      final map = Map<String, dynamic>.from(o);
      final id = map['id'] as String;
      return BulkOrder.fromJson(map, items: itemsByOrder[id] ?? []);
    }).toList();
  }

  /// Quote a bulk order item with a price and optional notes.
  /// Automatically updates order status if all items have been responded to.
  Future<void> quoteBulkOrderItem(
    String itemId,
    String farmerId,
    double price, {
    String? notes,
  }) async {
    if (price <= 0) {
      throw Exception('Price must be greater than 0');
    }

    // Verify ownership
    final item = await _client
        .from('bulk_order_items')
        .select('id, farmer_id, bulk_order_id, status')
        .eq('id', itemId)
        .single();

    if (item['farmer_id'] != farmerId) {
      throw Exception('Not authorized to quote this item');
    }
    if (item['status'] != 'pending') {
      throw Exception('Item is not in pending status');
    }

    await _client.from('bulk_order_items').update({
      'quoted_price_per_kg': price,
      'status': 'quoted',
      'farmer_notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
    }).eq('id', itemId);

    // Check if all items have been responded to
    await _checkAndUpdateOrderStatus(item['bulk_order_id'] as String);
  }

  /// Reject a bulk order item with optional notes.
  /// Automatically updates order status if all items have been responded to.
  Future<void> rejectBulkOrderItem(
    String itemId,
    String farmerId, {
    String? notes,
  }) async {
    // Verify ownership
    final item = await _client
        .from('bulk_order_items')
        .select('id, farmer_id, bulk_order_id, status')
        .eq('id', itemId)
        .single();

    if (item['farmer_id'] != farmerId) {
      throw Exception('Not authorized to reject this item');
    }
    if (item['status'] != 'pending') {
      throw Exception('Item is not in pending status');
    }

    await _client.from('bulk_order_items').update({
      'status': 'rejected',
      'farmer_notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
    }).eq('id', itemId);

    // Check if all items have been responded to
    await _checkAndUpdateOrderStatus(item['bulk_order_id'] as String);
  }

  // ---------------------------------------------------------------------------
  // Produce search (for creating bulk orders)
  // ---------------------------------------------------------------------------

  /// Search active produce listings by name. Used when creating bulk orders.
  Future<List<Map<String, dynamic>>> searchProduceListings(
    String query, {
    int limit = 20,
  }) async {
    // Escape PostgREST special chars to prevent filter injection
    final safeQuery = query.replaceAll(RegExp(r'[,.()\[\]\\]'), '');
    final result = await _client
        .from('produce_listings')
        .select('id, name_en, name_ne, price_per_kg, farmer_id, photos')
        .eq('is_active', true)
        .or('name_en.ilike.%$safeQuery%,name_ne.ilike.%$safeQuery%')
        .limit(limit);

    return List<Map<String, dynamic>>.from(result);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Check if all items in a bulk order have been responded to (quoted/rejected).
  /// If so, update the order status to 'quoted'.
  Future<void> _checkAndUpdateOrderStatus(String orderId) async {
    final items = await _client
        .from('bulk_order_items')
        .select('status')
        .eq('bulk_order_id', orderId);

    final allResponded = items.every((i) {
      final s = i['status'] as String;
      return s == 'quoted' || s == 'rejected';
    });

    if (allResponded && items.isNotEmpty) {
      await _client
          .from('bulk_orders')
          .update({'status': 'quoted'})
          .eq('id', orderId);
    }
  }

  static double _round2(double value) => (value * 100).round() / 100;
}

/// Input model for creating a bulk order item.
class BulkOrderItemInput {
  final String listingId;
  final double quantityKg;

  const BulkOrderItemInput({
    required this.listingId,
    required this.quantityKg,
  });
}
