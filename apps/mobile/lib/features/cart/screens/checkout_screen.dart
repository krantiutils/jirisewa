import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme.dart';
import '../../map/widgets/location_picker.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _addressController = TextEditingController();

  LatLng? _deliveryLocation;
  bool _pickingLocation = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _addressController.text = auth.profile?.address ?? '';
    _deliveryLocation = auth.profile?.location;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;

    if (userId == null) {
      setState(() => _error = 'You must be logged in');
      return;
    }
    if (cart.isEmpty) {
      setState(() => _error = 'Cart is empty');
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a delivery address');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Create order
      final orderData = {
        'consumer_id': userId,
        'status': OrderStatus.pending.dbValue,
        'delivery_address': _addressController.text.trim(),
        if (_deliveryLocation != null)
          'delivery_location':
              'POINT(${_deliveryLocation!.longitude} ${_deliveryLocation!.latitude})',
        'total_price': cart.totalPrice,
        'delivery_fee': 0, // Calculated when matched to a rider
        'payment_method': PaymentMethod.cash.name,
        'payment_status': PaymentStatus.pending.name,
      };

      final orderResult = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();

      final orderId = orderResult['id'] as String;

      // Create order items
      final items = cart.items.map((item) {
        return {
          'order_id': orderId,
          'listing_id': item.listing.id,
          'farmer_id': item.listing.farmerId,
          'quantity_kg': item.quantityKg,
          'price_per_kg': item.listing.pricePerKg,
          'subtotal': item.subtotal,
          if (item.listing.location != null)
            'pickup_location':
                'POINT(${item.listing.location!.longitude} ${item.listing.location!.latitude})',
        };
      }).toList();

      await _supabase.from('order_items').insert(items);

      // Clear cart
      cart.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      // Pop back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Failed to place order: ${e.toString().split(':').last.trim()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    if (_pickingLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Delivery Location')),
        body: LocationPickerWidget(
          initialLocation: _deliveryLocation,
          onLocationSelected: (location, address) {
            setState(() {
              _deliveryLocation = location;
              if (address.isNotEmpty) {
                _addressController.text = address;
              }
              _pickingLocation = false;
            });
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order summary
            Text('Order Summary',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...cart.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.listing.nameEn} (${item.quantityKg.toStringAsFixed(1)} kg)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text('NPR ${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Produce Total',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('NPR ${cart.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Delivery Fee',
                    style: TextStyle(color: Colors.grey[600])),
                Text('Calculated when matched',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment', style: TextStyle(color: Colors.grey[600])),
                const Text('Cash on Delivery',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),

            const SizedBox(height: 24),

            // Delivery address
            Text('Delivery Address',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                hintText: 'Enter your delivery address',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _pickingLocation = true),
              icon: const Icon(Icons.map),
              label: Text(_deliveryLocation != null
                  ? 'Change location on map'
                  : 'Pick location on map'),
            ),
            if (_deliveryLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Location set: ${_deliveryLocation!.latitude.toStringAsFixed(4)}, ${_deliveryLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submitting ? null : _placeOrder,
              child: Text(_submitting ? 'Placing Order...' : 'Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}
