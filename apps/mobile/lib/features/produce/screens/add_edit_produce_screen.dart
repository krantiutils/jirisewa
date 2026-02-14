import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/produce_category.dart';
import '../../../core/models/produce_listing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';

class AddEditProduceScreen extends StatefulWidget {
  final ProduceListing? listing;

  const AddEditProduceScreen({super.key, this.listing});

  @override
  State<AddEditProduceScreen> createState() => _AddEditProduceScreenState();
}

class _AddEditProduceScreenState extends State<AddEditProduceScreen> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  final _nameEnController = TextEditingController();
  final _nameNeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  List<ProduceCategory> _categories = [];
  String? _selectedCategoryId;
  DateTime? _freshnessDate;
  List<String> _photoUrls = [];
  bool _isActive = true;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (_isEditing) {
      final l = widget.listing!;
      _nameEnController.text = l.nameEn;
      _nameNeController.text = l.nameNe;
      _descriptionController.text = l.description ?? '';
      _priceController.text = l.pricePerKg.toStringAsFixed(0);
      _quantityController.text = l.availableQtyKg.toStringAsFixed(1);
      _selectedCategoryId = l.categoryId;
      _freshnessDate = l.freshnessDate;
      _photoUrls = List.from(l.photos);
      _isActive = l.isActive;
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameNeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
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

  Future<void> _pickPhoto() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (photo == null) return;

    try {
      final bytes = await photo.readAsBytes();
      final fileName =
          'listings/${DateTime.now().millisecondsSinceEpoch}_${photo.name}';

      await _supabase.storage
          .from('produce-photos')
          .uploadBinary(fileName, bytes);

      final url =
          _supabase.storage.from('produce-photos').getPublicUrl(fileName);

      setState(() => _photoUrls.add(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
    }
  }

  Future<void> _pickFreshnessDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _freshnessDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _freshnessDate = picked);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    if (_nameEnController.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price per kg');
      return;
    }
    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter available quantity');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = <String, dynamic>{
        'farmer_id': userId,
        'name_en': _nameEnController.text.trim(),
        'name_ne': _nameNeController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'price_per_kg': price,
        'available_qty_kg': qty,
        'is_active': _isActive,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        if (_freshnessDate != null)
          'freshness_date': _freshnessDate!.toIso8601String().split('T').first,
        if (_photoUrls.isNotEmpty) 'photos': _photoUrls,
      };

      if (_isEditing) {
        await _supabase
            .from('produce_listings')
            .update(data)
            .eq('id', widget.listing!.id);
      } else {
        await _supabase.from('produce_listings').insert(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _isEditing ? 'Listing updated!' : 'Listing created!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Listing' : 'Add Listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photos
            _label('Photos'),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photoUrls.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                entry.value,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 100,
                                  color: AppColors.muted,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                      () => _photoUrls.removeAt(entry.key));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Add',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name (English)
            _label('Name (English)'),
            TextField(
              controller: _nameEnController,
              decoration: const InputDecoration(hintText: 'e.g. Tomatoes'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Name (Nepali)
            _label('Name (Nepali)'),
            TextField(
              controller: _nameNeController,
              decoration: const InputDecoration(hintText: 'e.g. गोलभेडा'),
            ),
            const SizedBox(height: 16),

            // Category
            _label('Category'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(hintText: 'Select category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nameEn),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedCategoryId = value),
            ),
            const SizedBox(height: 16),

            // Price
            _label('Price per kg (NPR)'),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration:
                  const InputDecoration(hintText: 'e.g. 80', prefixText: 'NPR '),
            ),
            const SizedBox(height: 16),

            // Quantity
            _label('Available Quantity (kg)'),
            TextField(
              controller: _quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration:
                  const InputDecoration(hintText: 'e.g. 50', suffixText: 'kg'),
            ),
            const SizedBox(height: 16),

            // Freshness date
            _label('Harvest Date'),
            OutlinedButton.icon(
              onPressed: _pickFreshnessDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_freshnessDate != null
                  ? '${_freshnessDate!.day}/${_freshnessDate!.month}/${_freshnessDate!.year}'
                  : 'Select date'),
            ),
            const SizedBox(height: 16),

            // Description
            _label('Description (optional)'),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Describe your produce...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Active toggle
            SwitchListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('Active'),
              subtitle: const Text('Visible in marketplace when active'),
              contentPadding: EdgeInsets.zero,
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
              onPressed: _loading ? null : _submit,
              child: Text(_loading
                  ? 'Saving...'
                  : _isEditing
                      ? 'Update Listing'
                      : 'Create Listing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
