import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/farmer/providers/farmer_provider.dart';
import 'package:jirisewa_mobile/features/map/widgets/location_picker.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnController = TextEditingController();
  final _nameNeController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategoryId;
  String? _freshnessDate;
  LatLng? _selectedLocation;
  final List<String> _photoUrls = [];
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  String? _error;

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameNeController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_photoUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos allowed')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 1 MB')),
      );
      return;
    }

    final ext = _extensionFromPath(picked.name);
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPEG, PNG, and WebP are allowed')),
      );
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final profile = ref.read(userProfileProvider);
      if (profile == null) throw Exception('Not authenticated');

      final repo = ref.read(farmerRepositoryProvider);
      final url = await repo.uploadPhoto(
        profile.id,
        Uint8List.fromList(bytes),
        extension: ext,
      );

      if (!mounted) return;
      setState(() {
        _photoUrls.add(url);
        _isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoUrls.removeAt(index);
    });
  }

  Future<void> _pickFreshnessDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _freshnessDate = DateFormat('yyyy-MM-dd').format(date);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Please select a category');
      return;
    }

    final profile = ref.read(userProfileProvider);
    if (profile == null) {
      setState(() => _error = 'Not authenticated');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(farmerRepositoryProvider);
      await repo.createListing(
        farmerId: profile.id,
        categoryId: _selectedCategoryId!,
        nameEn: _nameEnController.text.trim(),
        nameNe: _nameNeController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        pricePerKg: double.parse(_priceController.text.trim()),
        availableQtyKg: double.parse(_qtyController.text.trim()),
        freshnessDate: _freshnessDate,
        photos: _photoUrls.isNotEmpty ? _photoUrls : null,
        location: _selectedLocation,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing created successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to create listing: $e';
      });
    }
  }

  void _onCategoryChanged(
    String? categoryId,
    List<Map<String, dynamic>> categories,
  ) {
    setState(() => _selectedCategoryId = categoryId);
    if (categoryId == null) return;

    final category = categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => <String, dynamic>{},
    );
    if (category.isEmpty) return;

    // Auto-populate name fields from category if they are empty.
    if (_nameEnController.text.isEmpty) {
      _nameEnController.text = (category['name_en'] as String?) ?? '';
    }
    if (_nameNeController.text.isEmpty) {
      _nameNeController.text = (category['name_ne'] as String?) ?? '';
    }
  }

  String _extensionFromPath(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return 'jpg';
    return parts.last.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Listing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load categories: $e')),
        data: (categories) => _buildForm(categories),
      ),
    );
  }

  Widget _buildForm(List<Map<String, dynamic>> categories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Category selector --
          Text(
            'Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            decoration: InputDecoration(
              hintText: 'Select a category',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.muted,
            ),
            items: categories.map((cat) {
              final icon = cat['icon'] as String?;
              final nameEn = cat['name_en'] as String? ?? '';
              return DropdownMenuItem<String>(
                value: cat['id'] as String,
                child: Row(
                  children: [
                    if (icon != null && icon.isNotEmpty) ...[
                      Text(icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                    ],
                    Text(nameEn),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => _onCategoryChanged(value, categories),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Category is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // -- Name English --
          Text(
            'Name (English)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameEnController,
            decoration: const InputDecoration(hintText: 'e.g. Fresh Tomatoes'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'English name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // -- Name Nepali --
          Text(
            'Name (Nepali)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameNeController,
            decoration: const InputDecoration(hintText: 'e.g. ताजा गोलभेडा'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nepali name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // -- Price per kg --
          Text(
            'Price per kg',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g. 120',
              prefixText: 'Rs ',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Price is required';
              }
              final price = double.tryParse(value.trim());
              if (price == null || price <= 0) {
                return 'Price must be greater than 0';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // -- Available quantity --
          Text(
            'Available Quantity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _qtyController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g. 50',
              suffixText: 'kg',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Quantity is required';
              }
              final qty = double.tryParse(value.trim());
              if (qty == null || qty <= 0) {
                return 'Quantity must be greater than 0';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // -- Freshness date --
          Text(
            'Freshness Date',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFreshnessDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: _freshnessDate != null
                        ? AppColors.primary
                        : Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _freshnessDate ?? 'Select freshness date (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      color: _freshnessDate != null
                          ? AppColors.foreground
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // -- Description --
          Text(
            'Description (optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your produce...',
            ),
          ),

          const SizedBox(height: 20),

          // -- Photos --
          Text(
            'Photos (max 5)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _PhotoGrid(
            photoUrls: _photoUrls,
            isUploading: _isUploadingPhoto,
            onAdd: _pickAndUploadPhoto,
            onRemove: _removePhoto,
          ),

          const SizedBox(height: 20),

          // -- Location (optional) --
          Text(
            'Location (optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 200,
              child: LocationPickerWidget(
                initialLocation: _selectedLocation,
                onLocationSelected: (LatLng location, String address) {
                  setState(() => _selectedLocation = location);
                },
              ),
            ),
          ),
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                'Lng: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

          const SizedBox(height: 24),

          // -- Error message --
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // -- Submit button --
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Listing'),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo grid widget
// ---------------------------------------------------------------------------

class _PhotoGrid extends StatelessWidget {
  final List<String> photoUrls;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _PhotoGrid({
    required this.photoUrls,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = photoUrls.length + (photoUrls.length < 5 ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Add button
        if (index == photoUrls.length) {
          return InkWell(
            onTap: isUploading ? null : onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 28, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          );
        }

        // Photo thumbnail
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photoUrls[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.muted,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
