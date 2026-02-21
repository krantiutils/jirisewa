import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jirisewa_mobile/features/cart/models/cart.dart';

const _cartKey = 'jirisewa_cart';

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  Completer<void>? _hydration;

  @override
  Cart build() {
    _hydration = Completer<void>();
    _loadFromStorage();
    return const Cart();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      if (cartJson != null && cartJson.isNotEmpty) {
        state = Cart.fromJsonString(cartJson);
      }
    } catch (_) {
      // Corrupted storage — start with empty cart.
    }
    _hydration?.complete();
  }

  Future<void> _ensureHydrated() async {
    await _hydration?.future;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, state.toJsonString());
  }

  Future<void> addItem(CartItem item) async {
    await _ensureHydrated();
    final existing =
        state.items.indexWhere((i) => i.listingId == item.listingId);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantityKg: updated[existing].quantityKg + item.quantityKg,
      );
      state = Cart(items: updated);
    } else {
      state = Cart(items: [...state.items, item]);
    }
    _persist();
  }

  Future<void> updateQuantity(String listingId, double quantityKg) async {
    await _ensureHydrated();
    if (quantityKg <= 0) {
      removeItem(listingId);
      return;
    }
    final updated = state.items.map((item) {
      if (item.listingId == listingId) {
        return item.copyWith(quantityKg: quantityKg);
      }
      return item;
    }).toList();
    state = Cart(items: updated);
    _persist();
  }

  Future<void> removeItem(String listingId) async {
    await _ensureHydrated();
    state = Cart(
        items: state.items.where((i) => i.listingId != listingId).toList());
    _persist();
  }

  void clear() {
    state = const Cart();
    _persist();
  }
}
