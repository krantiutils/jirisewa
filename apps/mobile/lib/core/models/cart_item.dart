import 'produce_listing.dart';

class CartItem {
  final ProduceListing listing;
  double quantityKg;

  CartItem({
    required this.listing,
    required this.quantityKg,
  });

  double get subtotal => listing.pricePerKg * quantityKg;
}
