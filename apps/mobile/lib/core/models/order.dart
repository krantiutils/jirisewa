import 'package:latlong2/latlong.dart';

import '../enums.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String listingId;
  final String farmerId;
  final double quantityKg;
  final double pricePerKg;
  final double subtotal;
  final LatLng? pickupLocation;
  final bool pickupConfirmed;
  final String? pickupPhotoUrl;
  final bool deliveryConfirmed;

  // Joined fields
  final String? listingNameEn;
  final String? listingNameNe;
  final String? farmerName;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.listingId,
    required this.farmerId,
    required this.quantityKg,
    required this.pricePerKg,
    required this.subtotal,
    this.pickupLocation,
    this.pickupConfirmed = false,
    this.pickupPhotoUrl,
    this.deliveryConfirmed = false,
    this.listingNameEn,
    this.listingNameNe,
    this.farmerName,
  });

  String listingName(String lang) =>
      lang == 'ne' && listingNameNe != null && listingNameNe!.isNotEmpty
          ? listingNameNe!
          : listingNameEn ?? '';

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    LatLng? pickupLoc;
    final locRaw = json['pickup_location'] as String?;
    if (locRaw != null) {
      final match =
          RegExp(r'POINT\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(locRaw);
      if (match != null) {
        pickupLoc = LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }
    }

    final listingData = json['listing'] as Map<String, dynamic>?;
    final farmerData = json['farmer'] as Map<String, dynamic>?;

    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      listingId: json['listing_id'] as String,
      farmerId: json['farmer_id'] as String,
      quantityKg: (json['quantity_kg'] as num).toDouble(),
      pricePerKg: (json['price_per_kg'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      pickupLocation: pickupLoc,
      pickupConfirmed: json['pickup_confirmed'] as bool? ?? false,
      pickupPhotoUrl: json['pickup_photo_url'] as String?,
      deliveryConfirmed: json['delivery_confirmed'] as bool? ?? false,
      listingNameEn: listingData?['name_en'] as String?,
      listingNameNe: listingData?['name_ne'] as String?,
      farmerName: farmerData?['name'] as String?,
    );
  }
}

class Order {
  final String id;
  final String consumerId;
  final String? riderTripId;
  final String? riderId;
  final OrderStatus status;
  final String deliveryAddress;
  final LatLng? deliveryLocation;
  final double totalPrice;
  final double deliveryFee;
  final double? deliveryFeeBase;
  final double? deliveryFeeDistance;
  final double? deliveryFeeWeight;
  final double? deliveryDistanceKm;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? consumerName;
  final String? riderName;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.consumerId,
    this.riderTripId,
    this.riderId,
    required this.status,
    required this.deliveryAddress,
    this.deliveryLocation,
    required this.totalPrice,
    required this.deliveryFee,
    this.deliveryFeeBase,
    this.deliveryFeeDistance,
    this.deliveryFeeWeight,
    this.deliveryDistanceKm,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.consumerName,
    this.riderName,
    this.items = const [],
  });

  double get grandTotal => totalPrice + deliveryFee;

  factory Order.fromJson(Map<String, dynamic> json) {
    LatLng? deliveryLoc;
    final locRaw = json['delivery_location'] as String?;
    if (locRaw != null) {
      final match =
          RegExp(r'POINT\(([\d.\-]+)\s+([\d.\-]+)\)').firstMatch(locRaw);
      if (match != null) {
        deliveryLoc = LatLng(
          double.parse(match.group(2)!),
          double.parse(match.group(1)!),
        );
      }
    }

    final consumerData = json['consumer'] as Map<String, dynamic>?;
    final riderData = json['rider'] as Map<String, dynamic>?;
    final itemsJson = json['order_items'] as List<dynamic>?;

    return Order(
      id: json['id'] as String,
      consumerId: json['consumer_id'] as String,
      riderTripId: json['rider_trip_id'] as String?,
      riderId: json['rider_id'] as String?,
      status: OrderStatus.fromDb(json['status'] as String? ?? 'pending'),
      deliveryAddress: json['delivery_address'] as String? ?? '',
      deliveryLocation: deliveryLoc,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      deliveryFeeBase: (json['delivery_fee_base'] as num?)?.toDouble(),
      deliveryFeeDistance: (json['delivery_fee_distance'] as num?)?.toDouble(),
      deliveryFeeWeight: (json['delivery_fee_weight'] as num?)?.toDouble(),
      deliveryDistanceKm: (json['delivery_distance_km'] as num?)?.toDouble(),
      paymentMethod:
          PaymentMethod.fromString(json['payment_method'] as String? ?? 'cash'),
      paymentStatus:
          PaymentStatus.fromString(json['payment_status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      consumerName: consumerData?['name'] as String?,
      riderName: riderData?['name'] as String?,
      items: itemsJson
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
