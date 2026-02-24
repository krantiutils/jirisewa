import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/business/models/business_profile.dart';
import 'package:jirisewa_mobile/features/business/providers/business_provider.dart';

/// Screen for registering a business profile or viewing/editing an existing one.
class BusinessRegisterScreen extends ConsumerStatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  ConsumerState<BusinessRegisterScreen> createState() =>
      _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState
    extends ConsumerState<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contactPersonController = TextEditingController();

  String _businessType = 'restaurant';
  bool _isSubmitting = false;
  bool _isEditing = false;
  String? _error;
  BusinessProfile? _existingProfile;

  @override
  void dispose() {
    _nameController.dispose();
    _regNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  void _populateFromProfile(BusinessProfile profile) {
    _existingProfile = profile;
    _nameController.text = profile.businessName;
    _businessType = profile.businessType;
    _regNumberController.text = profile.registrationNumber ?? '';
    _addressController.text = profile.address;
    _phoneController.text = profile.phone ?? '';
    _contactPersonController.text = profile.contactPerson ?? '';
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
      final repo = ref.read(businessRepositoryProvider);

      if (_existingProfile != null) {
        await repo.updateBusinessProfile(
          profileId: _existingProfile!.id,
          userId: profile.id,
          businessName: _nameController.text.trim(),
          businessType: _businessType,
          registrationNumber: _regNumberController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
        );
      } else {
        await repo.createBusinessProfile(
          userId: profile.id,
          businessName: _nameController.text.trim(),
          businessType: _businessType,
          registrationNumber: _regNumberController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          contactPerson: _contactPersonController.text.trim(),
        );
      }

      ref.invalidate(businessProfileProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existingProfile != null
                ? 'Profile updated successfully!'
                : 'Business registered successfully!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );

      context.go(AppRoutes.businessDashboard);
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
    final profileAsync = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _existingProfile != null ? 'Edit Business Profile' : 'Register Business',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load profile: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(businessProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (existingProfile) {
          // Populate form if profile exists and we haven't already
          if (existingProfile != null && _existingProfile == null && !_isEditing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _populateFromProfile(existingProfile);
                  _isEditing = true;
                });
              }
            });
          }

          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (existingProfile != null && !_isEditing) ...[
                    _ProfileCard(profile: existingProfile),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _populateFromProfile(existingProfile);
                          _isEditing = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.businessDashboard),
                      icon: const Icon(Icons.dashboard),
                      label: const Text('Go to Dashboard'),
                    ),
                  ] else ...[
                    // Business Name
                    _FieldLabel('Business Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Himalayan Kitchen',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Business Type
                    _FieldLabel('Business Type *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _businessType,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'restaurant',
                          child: Text('Restaurant'),
                        ),
                        DropdownMenuItem(
                          value: 'hotel',
                          child: Text('Hotel'),
                        ),
                        DropdownMenuItem(
                          value: 'canteen',
                          child: Text('Canteen'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _businessType = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Registration Number
                    _FieldLabel('Registration Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _regNumberController,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Address
                    _FieldLabel('Address *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Full business address',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _FieldLabel('Phone'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact Person
                    _FieldLabel('Contact Person'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                      ),
                    ),
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
                            border:
                                Border.all(color: AppColors.error.withAlpha(60)),
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
                          : Text(
                              _existingProfile != null
                                  ? 'Update Profile'
                                  : 'Register Business',
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Card (shown when profile exists and not editing)
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.businessTypeLabel,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (profile.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 14, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.location_on_outlined, text: profile.address),
            if (profile.phone != null && profile.phone!.isNotEmpty)
              _InfoRow(icon: Icons.phone_outlined, text: profile.phone!),
            if (profile.contactPerson != null &&
                profile.contactPerson!.isNotEmpty)
              _InfoRow(
                icon: Icons.person_outline,
                text: profile.contactPerson!,
              ),
            if (profile.registrationNumber != null &&
                profile.registrationNumber!.isNotEmpty)
              _InfoRow(
                icon: Icons.badge_outlined,
                text: 'Reg: ${profile.registrationNumber}',
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
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
