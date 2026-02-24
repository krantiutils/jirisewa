import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/addresses/models/saved_address.dart';
import 'package:jirisewa_mobile/features/addresses/providers/address_provider.dart';

/// Screen for managing saved delivery addresses with CRUD, swipe-to-delete,
/// and default address badge.
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  // ---------------------------------------------------------------------------
  // Add / Edit bottom sheet
  // ---------------------------------------------------------------------------

  void _showAddEditSheet({SavedAddress? existing}) {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final addressController =
        TextEditingController(text: existing?.addressText ?? '');
    bool isDefault = existing?.isDefault ?? false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(builderContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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

                  Text(
                    existing != null ? 'Edit Address' : 'Add Address',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Label field
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      hintText: 'Label (e.g. Home, Office)',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Address field
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      hintText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Default checkbox
                  CheckboxListTile(
                    value: isDefault,
                    onChanged: (v) {
                      setSheetState(() => isDefault = v ?? false);
                    },
                    title: const Text('Set as default'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(height: 12),

                  // Save button
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final label = labelController.text.trim();
                            final address = addressController.text.trim();
                            if (label.isEmpty || address.isEmpty) return;

                            final profile = ref.read(userProfileProvider);
                            if (profile == null) return;

                            setSheetState(() => isSubmitting = true);

                            try {
                              final repo =
                                  ref.read(addressRepositoryProvider);

                              if (existing != null) {
                                await repo.updateAddress(
                                  id: existing.id,
                                  userId: profile.id,
                                  label: label,
                                  addressText: address,
                                  isDefault: isDefault,
                                );
                              } else {
                                await repo.createAddress(
                                  userId: profile.id,
                                  label: label,
                                  addressText: address,
                                  lat: 0,
                                  lng: 0,
                                  isDefault: isDefault,
                                );
                              }

                              ref.invalidate(addressesProvider);

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save address: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(existing != null ? 'Update' : 'Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Saved Addresses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load addresses: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(addressesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No saved addresses',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(addressesProvider);
              await ref.read(addressesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressTile(
                  address: address,
                  onTap: () => _showAddEditSheet(existing: address),
                  onDismissed: () => _deleteAddress(address),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteAddress(SavedAddress address) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    try {
      final repo = ref.read(addressRepositoryProvider);
      await repo.deleteAddress(address.id, profile.id);
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete address: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Address tile widget
// ---------------------------------------------------------------------------

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onTap,
    required this.onDismissed,
  });

  final SavedAddress address;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(address.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: address.isDefault ? AppColors.primary : AppColors.border,
              width: address.isDefault ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Icon(
                address.isDefault ? Icons.star : Icons.location_on,
                color: address.isDefault
                    ? AppColors.accent
                    : AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),

              // Label + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.addressText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Default badge
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
