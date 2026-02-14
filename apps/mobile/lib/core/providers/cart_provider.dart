import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/produce_listing.dart';

/// In-memory cart state. Not persisted — resets on app restart.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  double get totalWeightKg =>
      _items.fold(0, (sum, item) => sum + item.quantityKg);

  void addItem(ProduceListing listing, double quantityKg) {
    final existingIndex =
        _items.indexWhere((item) => item.listing.id == listing.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantityKg += quantityKg;
    } else {
      _items.add(CartItem(listing: listing, quantityKg: quantityKg));
    }
    notifyListeners();
  }

  void updateQuantity(String listingId, double quantityKg) {
    final index = _items.indexWhere((item) => item.listing.id == listingId);
    if (index >= 0) {
      if (quantityKg <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantityKg = quantityKg;
      }
      notifyListeners();
    }
  }

  void removeItem(String listingId) {
    _items.removeWhere((item) => item.listing.id == listingId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
