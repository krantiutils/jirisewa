import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/farmer/providers/farmer_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // Current verification status from DB
  String? _roleId;
  String _verificationStatus = 'unverified';
  String? _adminNotes;

  // Existing document URLs from DB
  String? _existingCitizenshipUrl;
  String? _existingFarmUrl;
  String? _existingMunicipalityUrl;

  // Locally picked image bytes (not yet uploaded)
  Uint8List? _citizenshipBytes;
  String? _citizenshipExt;
  Uint8List? _farmBytes;
  String? _farmExt;
  Uint8List? _municipalityBytes;
  String? _municipalityExt;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) {
      setState(() {
        _isLoading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    try {
      final repo = ref.read(farmerRepositoryProvider);
      final result = await repo.getVerificationStatus(profile.id);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _error = 'No farmer role found';
        });
        return;
      }

      final doc = result['document'] as Map<String, dynamic>?;

      setState(() {
        _roleId = result['roleId'] as String?;
        _verificationStatus =
            (result['verificationStatus'] as String?) ?? 'unverified';
        _adminNotes = doc?['admin_notes'] as String?;
        _existingCitizenshipUrl = doc?['citizenship_photo_url'] as String?;
        _existingFarmUrl = doc?['farm_photo_url'] as String?;
        _existingMunicipalityUrl = doc?['municipality_letter_url'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load verification status: $e';
      });
    }
  }

  Future<void> _pickImage(String docType) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final ext = _extensionFromPath(picked.name);

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPEG, PNG, and WebP are allowed')),
      );
      return;
    }

    setState(() {
      switch (docType) {
        case 'citizenship':
          _citizenshipBytes = Uint8List.fromList(bytes);
          _citizenshipExt = ext;
        case 'farm':
          _farmBytes = Uint8List.fromList(bytes);
          _farmExt = ext;
        case 'municipality':
          _municipalityBytes = Uint8List.fromList(bytes);
          _municipalityExt = ext;
      }
    });
  }

  Future<void> _submit() async {
    // Require citizenship and farm photos
    final hasCitizenship =
        _citizenshipBytes != null || _existingCitizenshipUrl != null;
    final hasFarm = _farmBytes != null || _existingFarmUrl != null;

    if (!hasCitizenship || !hasFarm) {
      setState(() =>
          _error = 'Citizenship photo and farm photo are required');
      return;
    }

    if (_roleId == null) {
      setState(() => _error = 'No farmer role found');
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

      // Upload new photos if they were picked
      String citizenshipUrl = _existingCitizenshipUrl ?? '';
      if (_citizenshipBytes != null) {
        citizenshipUrl = await repo.uploadVerificationDoc(
          profile.id,
          _citizenshipBytes!,
          'citizenship',
          extension: _citizenshipExt ?? 'jpg',
        );
      }

      String farmUrl = _existingFarmUrl ?? '';
      if (_farmBytes != null) {
        farmUrl = await repo.uploadVerificationDoc(
          profile.id,
          _farmBytes!,
          'farm',
          extension: _farmExt ?? 'jpg',
        );
      }

      String? municipalityUrl = _existingMunicipalityUrl;
      if (_municipalityBytes != null) {
        municipalityUrl = await repo.uploadVerificationDoc(
          profile.id,
          _municipalityBytes!,
          'municipality',
          extension: _municipalityExt ?? 'jpg',
        );
      }

      await repo.submitVerification(
        _roleId!,
        citizenshipPhotoUrl: citizenshipUrl,
        farmPhotoUrl: farmUrl,
        municipalityLetterUrl: municipalityUrl,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _verificationStatus = 'pending';
        _existingCitizenshipUrl = citizenshipUrl;
        _existingFarmUrl = farmUrl;
        _existingMunicipalityUrl = municipalityUrl;
        // Clear local bytes since they have been uploaded
        _citizenshipBytes = null;
        _farmBytes = null;
        _municipalityBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification documents submitted!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Submission failed: $e';
      });
    }
  }

  String _extensionFromPath(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return 'jpg';
    return parts.last.toLowerCase();
  }

  bool get _isReadOnly =>
      _verificationStatus == 'pending' || _verificationStatus == 'verified';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 16),
                if (_verificationStatus == 'rejected' &&
                    _adminNotes != null &&
                    _adminNotes!.isNotEmpty)
                  _buildRejectionNote(),
                _buildDocumentSection(
                  title: 'Citizenship Photo',
                  required: true,
                  existingUrl: _existingCitizenshipUrl,
                  localBytes: _citizenshipBytes,
                  docType: 'citizenship',
                ),
                const SizedBox(height: 16),
                _buildDocumentSection(
                  title: 'Farm Photo',
                  required: true,
                  existingUrl: _existingFarmUrl,
                  localBytes: _farmBytes,
                  docType: 'farm',
                ),
                const SizedBox(height: 16),
                _buildDocumentSection(
                  title: 'Municipality Letter',
                  required: false,
                  existingUrl: _existingMunicipalityUrl,
                  localBytes: _municipalityBytes,
                  docType: 'municipality',
                ),
                const SizedBox(height: 24),
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
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isReadOnly)
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
                        : const Text('Submit Documents'),
                  ),
                SizedBox(
                    height: MediaQuery.of(context).viewPadding.bottom + 16),
              ],
            ),
    );
  }

  Widget _buildStatusBadge() {
    final Color badgeColor;
    final String label;
    final IconData icon;

    switch (_verificationStatus) {
      case 'verified':
        badgeColor = AppColors.secondary;
        label = 'Verified';
        icon = Icons.check_circle;
      case 'pending':
        badgeColor = AppColors.accent;
        label = 'Pending Review';
        icon = Icons.hourglass_empty;
      case 'rejected':
        badgeColor = AppColors.error;
        label = 'Rejected';
        icon = Icons.cancel;
      default:
        badgeColor = Colors.grey;
        label = 'Unverified';
        icon = Icons.info_outline;
    }

    return Card(
      elevation: 0,
      color: badgeColor.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: badgeColor.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: badgeColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionNote() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: AppColors.error.withAlpha(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.error.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.feedback_outlined,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _adminNotes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required bool required,
    required String? existingUrl,
    required Uint8List? localBytes,
    required String docType,
  }) {
    final hasImage = localBytes != null || existingUrl != null;

    return Card(
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                if (required)
                  const Text(
                    ' *',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: localBytes != null
                      ? Image.memory(
                          localBytes,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          existingUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.border,
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey, size: 40),
                            ),
                          ),
                        ),
                ),
              ),
            if (hasImage) const SizedBox(height: 8),
            if (!_isReadOnly)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(docType),
                  icon: Icon(
                    hasImage ? Icons.swap_horiz : Icons.add_photo_alternate,
                    size: 18,
                  ),
                  label: Text(hasImage ? 'Change Photo' : 'Select Photo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.foreground,
                  ),
                ),
              ),
            if (_isReadOnly && !hasImage)
              Text(
                'No document uploaded',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}
