import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/cart/models/cart.dart';
import 'package:jirisewa_mobile/features/cart/providers/cart_provider.dart';
import 'package:jirisewa_mobile/features/marketplace/providers/produce_detail_provider.dart';

/// Full produce detail screen with photo carousel, produce info, farmer info,
/// and a pinned add-to-cart bottom bar with quantity selector.
class ProduceDetailScreen extends ConsumerStatefulWidget {
  final String listingId;

  const ProduceDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ProduceDetailScreen> createState() =>
      _ProduceDetailScreenState();
}

class _ProduceDetailScreenState extends ConsumerState<ProduceDetailScreen> {
  double _quantity = 1.0;
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(produceDetailProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produce Detail'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load produce: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(produceDetailProvider(widget.listingId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text('Produce listing not found.'),
            );
          }
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> listing) {
    final photos = _parsePhotos(listing['photos']);
    final nameEn = listing['name_en'] as String? ?? 'Produce';
    final nameNe = listing['name_ne'] as String?;
    final pricePerKg = (listing['price_per_kg'] as num?)?.toDouble() ?? 0;
    final availableQty =
        (listing['available_qty_kg'] as num?)?.toDouble() ?? 0;
    final freshnessDate = listing['freshness_date'] as String?;
    final descriptionEn = listing['description_en'] as String?;

    final farmer = listing['users'] as Map<String, dynamic>?;
    final farmerName = farmer?['name'] as String? ?? 'Unknown Farmer';
    final farmerRating = (farmer?['rating_avg'] as num?)?.toDouble();
    final farmerRatingCount = (farmer?['rating_count'] as num?)?.toInt() ?? 0;

    final category = listing['produce_categories'] as Map<String, dynamic>?;
    final categoryName = category?['name_en'] as String?;
    final categoryIcon = category?['icon'] as String?;

    final municipality = listing['municipalities'] as Map<String, dynamic>?;
    final municipalityName = municipality?['name_en'] as String?;

    // Clamp quantity to available
    if (_quantity > availableQty && availableQty > 0) {
      _quantity = availableQty;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Carousel
                _photoCarousel(photos, categoryIcon),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        nameEn,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                      if (nameNe != null && nameNe.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          nameNe,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Price
                      Text(
                        'Rs. ${pricePerKg.toStringAsFixed(0)} /kg',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info chips row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _infoBadge(
                            Icons.inventory_2_outlined,
                            '${availableQty.toStringAsFixed(1)} kg available',
                            AppColors.secondary,
                          ),
                          if (freshnessDate != null)
                            _infoBadge(
                              Icons.schedule,
                              'Fresh: ${_formatDate(freshnessDate)}',
                              AppColors.primary,
                            ),
                          if (categoryName != null)
                            _infoBadge(
                              _categoryIconData(categoryIcon),
                              categoryName,
                              Colors.grey[700]!,
                            ),
                          if (municipalityName != null)
                            _infoBadge(
                              Icons.location_on_outlined,
                              municipalityName,
                              Colors.grey[700]!,
                            ),
                        ],
                      ),

                      // Description
                      if (descriptionEn != null &&
                          descriptionEn.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          descriptionEn,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Farmer section
                      _farmerSection(
                        farmerName,
                        farmerRating,
                        farmerRatingCount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom add-to-cart bar
        _addToCartBar(listing, availableQty),
      ],
    );
  }

  Widget _photoCarousel(List<String> photos, String? categoryIcon) {
    if (photos.isEmpty) {
      return Container(
        height: 280,
        width: double.infinity,
        color: AppColors.muted,
        child: Center(
          child: Icon(
            _categoryIconData(categoryIcon),
            size: 64,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() => _currentPhotoIndex = index);
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: photos[index],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: AppColors.muted,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.muted,
                  child: const Center(
                    child:
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
          // Dot indicators
          if (photos.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photos.length, (index) {
                  final isActive = index == _currentPhotoIndex;
                  return Container(
                    width: isActive ? 10 : 8,
                    height: isActive ? 10 : 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.primary
                          : Colors.white.withAlpha(180),
                      border: Border.all(
                        color: Colors.white.withAlpha(100),
                        width: 1,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _farmerSection(
    String farmerName,
    double? rating,
    int ratingCount,
  ) {
    final initial =
        farmerName.isNotEmpty ? farmerName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($ratingCount)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ] else
                      Text(
                        'No ratings yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _addToCartBar(Map<String, dynamic> listing, double availableQty) {
    final pricePerKg = (listing['price_per_kg'] as num?)?.toDouble() ?? 0;
    final subtotal = _quantity * pricePerKg;
    final canDecrease = _quantity > 0.5;
    final canIncrease = _quantity + 0.5 <= availableQty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Quantity selector
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _quantityButton(
                  Icons.remove,
                  canDecrease
                      ? () => setState(() => _quantity -= 0.5)
                      : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(
                    '${_quantity.toStringAsFixed(1)} kg',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _quantityButton(
                  Icons.add,
                  canIncrease
                      ? () => setState(() => _quantity += 0.5)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Add to cart button
          Expanded(
            child: ElevatedButton(
              onPressed: availableQty > 0
                  ? () => _addToCart(listing)
                  : null,
              child: Text(
                'Add to Cart - Rs. ${subtotal.toStringAsFixed(0)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 20,
          color: onPressed != null ? AppColors.foreground : Colors.grey[400],
        ),
      ),
    );
  }

  void _addToCart(Map<String, dynamic> listing) {
    final photos = _parsePhotos(listing['photos']);
    final farmer = listing['users'] as Map<String, dynamic>?;

    final item = CartItem(
      listingId: listing['id'] as String,
      farmerId: (farmer?['id'] as String?) ?? (listing['farmer_id'] as String),
      quantityKg: _quantity,
      pricePerKg: (listing['price_per_kg'] as num?)?.toDouble() ?? 0,
      nameEn: listing['name_en'] as String? ?? 'Produce',
      nameNe: listing['name_ne'] as String?,
      farmerName: farmer?['name'] as String? ?? 'Unknown Farmer',
      photo: photos.isNotEmpty ? photos.first : null,
    );

    ref.read(cartProvider.notifier).addItem(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.nameEn} (${_quantity.toStringAsFixed(1)} kg) added to cart',
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () {
            // Navigate to cart if needed - for now just dismiss
          },
        ),
      ),
    );
  }

  List<String> _parsePhotos(dynamic photos) {
    if (photos is List) {
      return photos
          .map((e) => e?.toString())
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  IconData _categoryIconData(String? icon) {
    // Map common category icon names to Material icons.
    switch (icon) {
      case 'grain':
        return Icons.grain;
      case 'eco':
        return Icons.eco;
      case 'local_florist':
        return Icons.local_florist;
      case 'grass':
        return Icons.grass;
      case 'apple':
      case 'nutrition':
        return Icons.apple;
      case 'egg':
        return Icons.egg;
      case 'set_meal':
        return Icons.set_meal;
      case 'spa':
        return Icons.spa;
      default:
        return Icons.eco_outlined;
    }
  }
}
