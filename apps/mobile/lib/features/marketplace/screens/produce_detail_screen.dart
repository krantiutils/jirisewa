import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/produce_listing.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme.dart';
import '../../cart/screens/cart_screen.dart';

class ProduceDetailScreen extends StatefulWidget {
  final String listingId;

  const ProduceDetailScreen({super.key, required this.listingId});

  @override
  State<ProduceDetailScreen> createState() => _ProduceDetailScreenState();
}

class _ProduceDetailScreenState extends State<ProduceDetailScreen> {
  final _supabase = Supabase.instance.client;

  ProduceListing? _listing;
  bool _loading = true;
  double _quantity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    try {
      final data = await _supabase
          .from('produce_listings')
          .select(
              '*, farmer:users!farmer_id(name, phone, rating_avg), category:produce_categories(name_en, name_ne)')
          .eq('id', widget.listingId)
          .single();

      if (!mounted) return;
      setState(() {
        _listing = ProduceListing.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _addToCart() {
    if (_listing == null) return;
    final cart = context.read<CartProvider>();
    cart.addItem(_listing!, _quantity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_listing!.nameEn} added to cart'),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_listing?.nameEn ?? 'Produce'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _listing == null
              ? const Center(child: Text('Listing not found'))
              : _buildContent(),
      bottomNavigationBar: _listing != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildContent() {
    final listing = _listing!;
    final dateFormat = DateFormat('MMM d, yyyy');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo carousel
          SizedBox(
            height: 250,
            child: listing.photos.isNotEmpty
                ? PageView.builder(
                    itemCount: listing.photos.length,
                    itemBuilder: (context, index) => Image.network(
                      listing.photos[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.muted,
                        child: const Center(
                          child: Icon(Icons.eco,
                              size: 60, color: AppColors.secondary),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.muted,
                    child: const Center(
                      child:
                          Icon(Icons.eco, size: 60, color: AppColors.secondary),
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + price
                Text(
                  listing.nameEn,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (listing.nameNe.isNotEmpty &&
                    listing.nameNe != listing.nameEn)
                  Text(listing.nameNe,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(
                  'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Category
                if (listing.categoryNameEn != null)
                  _infoRow(Icons.category, 'Category',
                      listing.categoryNameEn!),

                // Availability
                _infoRow(Icons.inventory_2, 'Available',
                    '${listing.availableQtyKg.toStringAsFixed(1)} kg'),

                // Freshness
                if (listing.freshnessDate != null)
                  _infoRow(Icons.calendar_today, 'Harvested',
                      dateFormat.format(listing.freshnessDate!)),

                // Description
                if (listing.description != null &&
                    listing.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Description',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(listing.description!,
                      style: TextStyle(color: Colors.grey[700])),
                ],

                const SizedBox(height: 24),

                // Farmer info
                const Text('Farmer',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondary.withAlpha(30),
                      child: const Icon(Icons.person,
                          color: AppColors.secondary),
                    ),
                    title: Text(listing.farmerName ?? 'Unknown'),
                    subtitle: listing.farmerRatingAvg != null &&
                            listing.farmerRatingAvg! > 0
                        ? Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(listing.farmerRatingAvg!
                                  .toStringAsFixed(1)),
                            ],
                          )
                        : const Text('New farmer'),
                  ),
                ),

                const SizedBox(height: 24),

                // Quantity selector
                const Text('Quantity (kg)',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _quantity > 0.5
                          ? () => setState(() => _quantity -= 0.5)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${_quantity.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 16),
                    IconButton.outlined(
                      onPressed: _quantity < listing.availableQtyKg
                          ? () => setState(() => _quantity += 0.5)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Subtotal: NPR ${(_quantity * listing.pricePerKg).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 80), // Space for bottom bar
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _addToCart,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(
            'Add to Cart — NPR ${(_quantity * _listing!.pricePerKg).toStringAsFixed(0)}',
          ),
        ),
      ),
    );
  }
}
