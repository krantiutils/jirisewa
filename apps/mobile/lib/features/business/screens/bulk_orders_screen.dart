import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/business/models/bulk_order.dart';
import 'package:jirisewa_mobile/features/business/providers/business_provider.dart';
import 'package:jirisewa_mobile/features/business/repositories/business_repository.dart';

/// Screen listing bulk orders with status filter tabs and order creation.
class BulkOrdersScreen extends ConsumerStatefulWidget {
  const BulkOrdersScreen({super.key});

  @override
  ConsumerState<BulkOrdersScreen> createState() => _BulkOrdersScreenState();
}

class _BulkOrdersScreenState extends ConsumerState<BulkOrdersScreen> {
  String _statusFilter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('submitted', 'Submitted'),
    ('quoted', 'Quoted'),
    ('accepted', 'Accepted'),
    ('in_progress', 'Active'),
    ('fulfilled', 'Fulfilled'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(bulkOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Bulk Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (value, label) = _filters[index];
                final isSelected = _statusFilter == value;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _statusFilter = value),
                  selectedColor: AppColors.primary.withAlpha(30),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Orders list
          Expanded(
            child: ordersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load orders: $error'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(bulkOrdersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (orders) {
                final filtered = _statusFilter == 'all'
                    ? orders
                    : orders
                        .where((o) => o.status == _statusFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(bulkOrdersProvider);
                      await ref.read(bulkOrdersProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _statusFilter == 'all'
                                    ? 'No bulk orders yet'
                                    : 'No $_statusFilter orders',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to create your first order',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(bulkOrdersProvider);
                    await ref.read(bulkOrdersProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _OrderCard(order: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOrderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CreateOrderSheet(ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Order Card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final BulkOrder order;

  Color get _statusColor {
    switch (order.status) {
      case 'submitted':
        return AppColors.primary;
      case 'quoted':
        return AppColors.accent;
      case 'accepted':
      case 'fulfilled':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/business/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    order.frequencyLabel,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              // Item count
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Order Bottom Sheet
// ---------------------------------------------------------------------------

class _CreateOrderSheet extends ConsumerStatefulWidget {
  const _CreateOrderSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends ConsumerState<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  String _frequency = 'once';
  final List<_OrderItemEntry> _items = [];
  bool _isSubmitting = false;
  bool _isSearching = false;
  String? _error;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    for (final item in _items) {
      item.qtyController.dispose();
    }
    super.dispose();
  }

  Future<void> _searchProduce(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final repo = ref.read(businessRepositoryProvider);
      final results = await repo.searchProduceListings(query.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _addItem(Map<String, dynamic> listing) {
    // Check if already added
    final listingId = listing['id'] as String;
    if (_items.any((i) => i.listingId == listingId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item already added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _items.add(_OrderItemEntry(
        listingId: listingId,
        nameEn: listing['name_en'] as String? ?? '',
        nameNe: listing['name_ne'] as String? ?? '',
        pricePerKg: (listing['price_per_kg'] as num?)?.toDouble() ?? 0,
        farmerId: listing['farmer_id'] as String? ?? '',
      ));
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].qtyController.dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }

    // Validate quantities
    for (final item in _items) {
      final qty = double.tryParse(item.qtyController.text.trim());
      if (qty == null || qty <= 0) {
        setState(() => _error = 'All items must have a valid quantity');
        return;
      }
    }

    final bizProfile = await ref.read(businessProfileProvider.future);
    if (bizProfile == null) {
      setState(() => _error = 'Business profile not found');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(businessRepositoryProvider);
      final itemInputs = _items.map((item) {
        return BulkOrderItemInput(
          listingId: item.listingId,
          quantityKg: double.parse(item.qtyController.text.trim()),
        );
      }).toList();

      await repo.createBulkOrder(
        businessId: bizProfile.id,
        deliveryAddress: _addressController.text.trim(),
        deliveryFrequency: _frequency,
        notes: _notesController.text.trim(),
        items: itemInputs,
      );

      ref.invalidate(bulkOrdersProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Create Bulk Order',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Delivery Address
              _FieldLabel('Delivery Address *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Full delivery address',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Delivery Frequency
              _FieldLabel('Delivery Frequency'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'once', child: Text('One-time')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),
              const SizedBox(height: 16),

              // Notes
              _FieldLabel('Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Any special requirements...',
                ),
              ),
              const SizedBox(height: 24),

              // Search produce
              const Text(
                'Add Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search produce...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _searchProduce,
              ),

              // Search results
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final listing = _searchResults[index];
                      final nameEn = listing['name_en'] as String? ?? '';
                      final price =
                          (listing['price_per_kg'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        dense: true,
                        title: Text(
                          nameEn,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Text(
                          'Rs ${price.toStringAsFixed(0)}/kg',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () => _addItem(listing),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),

              // Added items
              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'No items added yet. Search and add produce above.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),

              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _OrderItemRow(
                  item: item,
                  index: index,
                  onRemove: () => _removeItem(index),
                );
              }),

              const SizedBox(height: 24),

              // Error
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
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Submit
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
                    : const Text('Submit Order'),
              ),

              SizedBox(
                height: MediaQuery.of(context).viewPadding.bottom + 16,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Order Item Entry
// ---------------------------------------------------------------------------

class _OrderItemEntry {
  final String listingId;
  final String nameEn;
  final String nameNe;
  final double pricePerKg;
  final String farmerId;
  final qtyController = TextEditingController();

  _OrderItemEntry({
    required this.listingId,
    required this.nameEn,
    required this.nameNe,
    required this.pricePerKg,
    required this.farmerId,
  });
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.index,
    required this.onRemove,
  });

  final _OrderItemEntry item;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.nameEn,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'Rs ${item.pricePerKg.toStringAsFixed(0)}/kg',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: item.qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  suffixText: 'kg',
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final qty = double.tryParse(v.trim());
                  if (qty == null || qty <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field label widget
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }
}
