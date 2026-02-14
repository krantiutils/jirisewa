import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/produce_category.dart';
import '../../../core/models/produce_listing.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/theme.dart';
import '../../cart/screens/cart_screen.dart';
import 'produce_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<ProduceCategory> _categories = [];
  List<ProduceListing> _listings = [];
  String? _selectedCategoryId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _supabase
          .from('produce_categories')
          .select()
          .order('sort_order');

      if (!mounted) return;
      setState(() {
        _categories = (data as List)
            .map((j) => ProduceCategory.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var query = _supabase
          .from('produce_listings')
          .select(
              '*, farmer:users!farmer_id(name, phone, rating_avg), category:produce_categories(name_en, name_ne)')
          .eq('is_active', true);

      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final searchQuery = _searchController.text.trim();
      if (searchQuery.isNotEmpty) {
        query = query.or('name_en.ilike.%$searchQuery%,name_ne.ilike.%$searchQuery%');
      }

      final data = await query.order('created_at', ascending: false).limit(50);

      if (!mounted) return;
      setState(() {
        _listings = (data as List)
            .map((j) => ProduceListing.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load produce. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            icon: cart.itemCount > 0
                ? Badge.count(
                    count: cart.itemCount,
                    child: const Icon(Icons.shopping_cart_outlined),
                  )
                : const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadListings,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search produce...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadListings();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _loadListings(),
              ),
            ),

            // Category chips
            if (_categories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _categoryChip(null, 'All'),
                    ..._categories.map(
                      (c) => _categoryChip(c.id, c.nameEn),
                    ),
                  ],
                ),
              ),

            // Listings grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.error)),
                        )
                      : _listings.isEmpty
                          ? const Center(
                              child: Text('No produce found',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _listings.length,
                              itemBuilder: (context, index) =>
                                  _buildListingCard(_listings[index]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String? id, String label) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategoryId = id);
          _loadListings();
        },
        selectedColor: AppColors.primary.withAlpha(30),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildListingCard(ProduceListing listing) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProduceDetailScreen(listingId: listing.id),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: AppColors.muted,
                child: listing.photos.isNotEmpty
                    ? Image.network(
                        listing.photos.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.eco, size: 40, color: AppColors.secondary),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.eco, size: 40, color: AppColors.secondary),
                      ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.nameEn,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (listing.farmerName != null)
                      Text(
                        listing.farmerName!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${listing.availableQtyKg.toStringAsFixed(0)} kg available',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
