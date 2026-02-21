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

class EditListingScreen extends ConsumerStatefulWidget {
  final String listingId;

  const EditListingScreen({super.key, required this.listingId});

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnController = TextEditingController();
  final _nameNeController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategoryId;
  String? _freshnessDate;
  LatLng? _selectedLocation;
  List<String> _photoUrls = [];
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _isDeactivating = false;
  bool _initialized = false;
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

  void _initializeFromListing(Map<String, dynamic> listing) {
    if (_initialized) return;
    _initialized = true;

    _nameEnController.text = (listing['name_en'] as String?) ?? '';
    _nameNeController.text = (listing['name_ne'] as String?) ?? '';
    _priceController.text =
        (listing['price_per_kg'] as num?)?.toString() ?? '';
    _qtyController.text =
        (listing['available_qty_kg'] as num?)?.toString() ?? '';
    _descriptionController.text =
        (listing['description'] as String?) ?? '';
    _selectedCategoryId = listing['category_id'] as String?;
    _freshnessDate = listing['freshness_date'] as String?;
    _isActive = (listing['is_active'] as bool?) ?? true;

    // Parse photos array
    final photos = listing['photos'];
    if (photos is List) {
      _photoUrls = photos.cast<String>().toList();
    }

    // Parse location from PostGIS — listing may contain location as string or null
    // We skip location pre-fill since PostGIS geography isn't easily parseable
    // from the raw select result without extra RPC.
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
    final initial = _freshnessDate != null
        ? DateTime.tryParse(_freshnessDate!) ?? now
        : now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
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

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(farmerRepositoryProvider);
      await repo.updateListing(
        widget.listingId,
        categoryId: _selectedCategoryId,
        nameEn: _nameEnController.text.trim(),
        nameNe: _nameNeController.text.trim(),
        description: _descriptionController.text.trim(),
        pricePerKg: double.parse(_priceController.text.trim()),
        availableQtyKg: double.parse(_qtyController.text.trim()),
        freshnessDate: _freshnessDate,
        photos: _photoUrls,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing updated successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to update listing: $e';
      });
    }
  }

  Future<void> _toggleDeactivate() async {
    final newActiveState = !_isActive;
    final action = newActiveState ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newActiveState ? 'Activate' : 'Deactivate'} Listing?'),
        content: Text(
          newActiveState
              ? 'This listing will become visible to consumers again.'
              : 'This listing will be hidden from consumers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              action[0].toUpperCase() + action.substring(1),
              style: TextStyle(
                color: newActiveState ? AppColors.secondary : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeactivating = true);

    try {
      final repo = ref.read(farmerRepositoryProvider);
      await repo.toggleActive(widget.listingId, newActiveState);

      if (!mounted) return;

      setState(() {
        _isActive = newActiveState;
        _isDeactivating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newActiveState
                ? 'Listing activated'
                : 'Listing deactivated',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              newActiveState ? AppColors.secondary : AppColors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeactivating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $action listing: $e')),
      );
    }
  }

  String _extensionFromPath(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return 'jpg';
    return parts.last.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(farmerListingProvider(widget.listingId));
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Listing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        actions: [
          if (_initialized)
            IconButton(
              onPressed: _isDeactivating ? null : _toggleDeactivate,
              icon: _isDeactivating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isActive
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _isActive ? AppColors.error : AppColors.secondary,
                    ),
              tooltip: _isActive ? 'Deactivate' : 'Activate',
            ),
        ],
      ),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load listing: $e')),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Listing not found'));
          }

          _initializeFromListing(listing);

          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load categories: $e')),
            data: (categories) => _buildForm(categories),
          );
        },
      ),
    );
  }

  Widget _buildForm(List<Map<String, dynamic>> categories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Active status banner --
          if (!_isActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off,
                      size: 18, color: AppColors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This listing is currently deactivated and hidden from consumers.',
                      style:
                          TextStyle(color: AppColors.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

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
            onChanged: (value) {
              setState(() => _selectedCategoryId = value);
            },
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
                : const Text('Save Changes'),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo grid widget (duplicated from create screen for self-containment)
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
