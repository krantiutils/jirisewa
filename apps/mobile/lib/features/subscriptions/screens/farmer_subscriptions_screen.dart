import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/subscriptions/models/subscription_plan.dart';
import 'package:jirisewa_mobile/features/subscriptions/providers/subscription_provider.dart';

/// Farmer screen for creating and managing subscription plans.
class FarmerSubscriptionsScreen extends ConsumerWidget {
  const FarmerSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(farmerSubscriptionPlansProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Subscription Plans',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlanSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load plans: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(farmerSubscriptionPlansProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (plans) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(farmerSubscriptionPlansProvider);
            await ref.read(farmerSubscriptionPlansProvider.future);
          },
          child: plans.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.3,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.subscriptions_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No subscription plans yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create your first plan',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: plans.length,
                  itemBuilder: (context, index) =>
                      _FarmerPlanCard(plan: plans[index]),
                ),
        ),
      ),
    );
  }

  void _showCreatePlanSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CreatePlanSheet(ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer Plan Card
// ---------------------------------------------------------------------------

class _FarmerPlanCard extends ConsumerWidget {
  const _FarmerPlanCard({required this.plan});
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name + active toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.nameEn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: plan.isActive,
                  activeThumbColor: AppColors.secondary,
                  onChanged: (value) => _toggleActive(context, ref, value),
                ),
              ],
            ),

            if (plan.nameNe.isNotEmpty)
              Text(
                plan.nameNe,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),

            const SizedBox(height: 8),

            // Price and frequency
            Row(
              children: [
                Text(
                  'Rs ${plan.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  ' / ${plan.frequency}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${plan.subscriberCount}/${plan.maxSubscribers}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Delivery day
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Delivery: ${plan.deliveryDayLabel}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            // Items
            if (plan.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: plan.items.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${item.categoryEn} ~${item.approxKg.toStringAsFixed(1)}kg',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Status indicator
            if (!plan.isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    bool isActive,
  ) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.togglePlan(plan.id, profile.id, isActive);
      ref.invalidate(farmerSubscriptionPlansProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update plan: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Create Plan Bottom Sheet
// ---------------------------------------------------------------------------

class _CreatePlanSheet extends ConsumerStatefulWidget {
  const _CreatePlanSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends ConsumerState<_CreatePlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnController = TextEditingController();
  final _nameNeController = TextEditingController();
  final _descEnController = TextEditingController();
  final _descNeController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxSubsController = TextEditingController();

  String _frequency = 'weekly';
  int _deliveryDay = 0;
  final List<_ItemEntry> _items = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameNeController.dispose();
    _descEnController.dispose();
    _descNeController.dispose();
    _priceController.dispose();
    _maxSubsController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemEntry());
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
      final items = _items.map((entry) {
        return SubscriptionPlanItem(
          categoryEn: entry.categoryEnController.text.trim(),
          categoryNe: entry.categoryNeController.text.trim(),
          approxKg: double.tryParse(entry.kgController.text.trim()) ?? 0,
        );
      }).toList();

      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.createPlan(
        farmerId: profile.id,
        nameEn: _nameEnController.text.trim(),
        nameNe: _nameNeController.text.trim(),
        descriptionEn: _descEnController.text.trim(),
        descriptionNe: _descNeController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        frequency: _frequency,
        items: items,
        maxSubscribers: int.parse(_maxSubsController.text.trim()),
        deliveryDay: _deliveryDay,
      );

      ref.invalidate(farmerSubscriptionPlansProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan created successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Failed to create plan: $e';
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
                'Create Subscription Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Name (English)
              _FieldLabel('Name (English)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameEnController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Weekly Veggie Box',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Name (Nepali)
              _FieldLabel('Name (Nepali)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameNeController,
                decoration: const InputDecoration(
                  hintText: 'e.g. साप्ताहिक तरकारी बक्स',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Description (English)
              _FieldLabel('Description (English)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descEnController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Describe your subscription plan...',
                ),
              ),

              const SizedBox(height: 16),

              // Description (Nepali)
              _FieldLabel('Description (Nepali)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descNeController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'तपाईंको सदस्यता योजना वर्णन गर्नुहोस्...',
                ),
              ),

              const SizedBox(height: 16),

              // Price
              _FieldLabel('Price (NPR)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. 500',
                  prefixText: 'Rs ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final price = double.tryParse(v.trim());
                  if (price == null || price <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Frequency
              _FieldLabel('Frequency'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _frequency = v);
                },
              ),

              const SizedBox(height: 16),

              // Max subscribers
              _FieldLabel('Max Subscribers'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _maxSubsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: 'e.g. 20'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Delivery day
              _FieldLabel('Delivery Day'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _deliveryDay,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _deliveryDay = v);
                },
              ),

              const SizedBox(height: 24),

              // Items section
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Box Items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'No items added yet. Items describe what the box contains.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),

              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _ItemRow(
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
                    : const Text('Create Plan'),
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
// Item entry (holds controllers for a single box item)
// ---------------------------------------------------------------------------

class _ItemEntry {
  final categoryEnController = TextEditingController();
  final categoryNeController = TextEditingController();
  final kgController = TextEditingController();

  void dispose() {
    categoryEnController.dispose();
    categoryNeController.dispose();
    kgController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Item row widget
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.index,
    required this.onRemove,
  });

  final _ItemEntry item;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
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
            TextFormField(
              controller: item.categoryEnController,
              decoration: const InputDecoration(
                hintText: 'Category (English)',
                isDense: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.categoryNeController,
              decoration: const InputDecoration(
                hintText: 'Category (Nepali)',
                isDense: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.kgController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: const InputDecoration(
                hintText: 'Approx kg',
                suffixText: 'kg',
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final kg = double.tryParse(v.trim());
                if (kg == null || kg <= 0) return 'Must be > 0';
                return null;
              },
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
