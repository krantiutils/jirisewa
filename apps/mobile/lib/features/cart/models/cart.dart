import 'dart:convert';

class CartItem {
  final String listingId;
  final String farmerId;
  final double quantityKg;
  final double pricePerKg;
  final String nameEn;
  final String? nameNe;
  final String farmerName;
  final String? photo;

  const CartItem({
    required this.listingId,
    required this.farmerId,
    required this.quantityKg,
    required this.pricePerKg,
    required this.nameEn,
    this.nameNe,
    required this.farmerName,
    this.photo,
  });

  double get subtotal => quantityKg * pricePerKg;

  CartItem copyWith({double? quantityKg}) {
    return CartItem(
      listingId: listingId,
      farmerId: farmerId,
      quantityKg: quantityKg ?? this.quantityKg,
      pricePerKg: pricePerKg,
      nameEn: nameEn,
      nameNe: nameNe,
      farmerName: farmerName,
      photo: photo,
    );
  }

  Map<String, dynamic> toJson() => {
        'listingId': listingId,
        'farmerId': farmerId,
        'quantityKg': quantityKg,
        'pricePerKg': pricePerKg,
        'nameEn': nameEn,
        'nameNe': nameNe,
        'farmerName': farmerName,
        'photo': photo,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        listingId: json['listingId'] as String,
        farmerId: json['farmerId'] as String,
        quantityKg: (json['quantityKg'] as num).toDouble(),
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        nameEn: json['nameEn'] as String,
        nameNe: json['nameNe'] as String?,
        farmerName: json['farmerName'] as String,
        photo: json['photo'] as String?,
      );
}

class Cart {
  final List<CartItem> items;
  const Cart({this.items = const []});

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalKg => items.fold(0, (sum, item) => sum + item.quantityKg);
  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;

  /// Group items by farmerId.
  Map<String, List<CartItem>> get byFarmer {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.farmerId, () => []).add(item);
    }
    return map;
  }

  String toJsonString() => json.encode(items.map((i) => i.toJson()).toList());

  factory Cart.fromJsonString(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return Cart(
      items: list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
