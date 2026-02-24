/// An item within a bulk order, with optional listing and farmer details.
class BulkOrderItem {
  final String id;
  final String bulkOrderId;
  final String produceListingId;
  final String farmerId;
  final double quantityKg;
  final double pricePerKg;
  final double? quotedPricePerKg;
  final String status; // pending, quoted, accepted, rejected, cancelled
  final String? farmerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined listing info
  final String? listingNameEn;
  final String? listingNameNe;
  final List<String> listingPhotos;

  // Joined farmer info
  final String? farmerName;
  final String? farmerAvatarUrl;

  const BulkOrderItem({
    required this.id,
    required this.bulkOrderId,
    required this.produceListingId,
    required this.farmerId,
    required this.quantityKg,
    required this.pricePerKg,
    this.quotedPricePerKg,
    required this.status,
    this.farmerNotes,
    required this.createdAt,
    required this.updatedAt,
    this.listingNameEn,
    this.listingNameNe,
    this.listingPhotos = const [],
    this.farmerName,
    this.farmerAvatarUrl,
  });

  factory BulkOrderItem.fromJson(Map<String, dynamic> json) {
    // Parse joined listing data
    final listing = json['produce_listings'] as Map<String, dynamic>?;
    final rawPhotos = listing?['photos'];
    final photos = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p is String) photos.add(p);
      }
    }

    // Parse joined farmer data
    final farmer = json['users'] as Map<String, dynamic>?;

    return BulkOrderItem(
      id: json['id'] as String,
      bulkOrderId: json['bulk_order_id'] as String,
      produceListingId: json['produce_listing_id'] as String,
      farmerId: json['farmer_id'] as String,
      quantityKg: (json['quantity_kg'] as num?)?.toDouble() ?? 0,
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble() ?? 0,
      quotedPricePerKg: (json['quoted_price_per_kg'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      farmerNotes: json['farmer_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      listingNameEn: listing?['name_en'] as String?,
      listingNameNe: listing?['name_ne'] as String?,
      listingPhotos: photos,
      farmerName: farmer?['name'] as String?,
      farmerAvatarUrl: farmer?['avatar_url'] as String?,
    );
  }

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'quoted':
        return 'Quoted';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// A bulk order placed by a business, with embedded items.
class BulkOrder {
  final String id;
  final String businessId;
  final String status; // draft, submitted, quoted, accepted, in_progress, fulfilled, cancelled
  final String deliveryAddress;
  final String? deliveryLocation;
  final String deliveryFrequency; // once, weekly, biweekly, monthly
  final Map<String, dynamic>? deliverySchedule;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BulkOrderItem> items;

  const BulkOrder({
    required this.id,
    required this.businessId,
    required this.status,
    required this.deliveryAddress,
    this.deliveryLocation,
    required this.deliveryFrequency,
    this.deliverySchedule,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory BulkOrder.fromJson(
    Map<String, dynamic> json, {
    List<BulkOrderItem> items = const [],
  }) {
    Map<String, dynamic>? schedule;
    if (json['delivery_schedule'] is Map) {
      schedule = Map<String, dynamic>.from(json['delivery_schedule'] as Map);
    }

    return BulkOrder(
      id: json['id'] as String,
      businessId: json['business_id'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      deliveryLocation: json['delivery_location'] as String?,
      deliveryFrequency: json['delivery_frequency'] as String? ?? 'once',
      deliverySchedule: schedule,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: items,
    );
  }

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'quoted':
        return 'Quoted';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'fulfilled':
        return 'Fulfilled';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Human-readable frequency label.
  String get frequencyLabel {
    switch (deliveryFrequency) {
      case 'once':
        return 'One-time';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Biweekly';
      case 'monthly':
        return 'Monthly';
      default:
        return deliveryFrequency;
    }
  }

  /// Whether this order can be cancelled.
  bool get isCancellable =>
      status == 'draft' || status == 'submitted' || status == 'quoted';

  /// Whether this order can be accepted (all items quoted).
  bool get isAcceptable => status == 'quoted';
}
