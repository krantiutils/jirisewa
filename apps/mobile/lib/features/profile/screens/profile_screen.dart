import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/theme.dart';

/// Profile screen: view/edit name, phone, address, language preference, role details.
/// Includes language switcher (en/ne) and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _municipalityController;
  late String _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resetForm();
  }

  void _resetForm() {
    final profile = SessionProvider.of(context).profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _addressController = TextEditingController(text: profile?.address ?? '');
    _municipalityController = TextEditingController(text: profile?.municipality ?? '');
    _lang = profile?.lang ?? 'ne';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _municipalityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final session = SessionProvider.read(context);
      await session.updateProfile(
        name: name,
        address: _addressController.text.trim(),
        municipality: _municipalityController.text.trim(),
        lang: _lang,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final session = SessionProvider.read(context);
    await session.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionProvider.of(context);
    final profile = session.profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_editing)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => setState(() => _editing = true),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar + name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _roleColor(session.activeRole).withAlpha(50),
                      child: Text(
                        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _roleColor(session.activeRole),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_editing) ...[
                      Text(
                        profile.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.phone,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                    if (profile.ratingCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: AppColors.accent, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.ratingAvg.toStringAsFixed(1)} (${profile.ratingCount})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Edit form or read-only details
              if (_editing) ...[
                _label('Full Name'),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Your full name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _label('Address'),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(hintText: 'Your address'),
                ),
                const SizedBox(height: 16),
                _label('Municipality'),
                TextField(
                  controller: _municipalityController,
                  decoration: const InputDecoration(hintText: 'e.g. Jiri, Kathmandu'),
                ),
                const SizedBox(height: 16),
                _label('Language'),
                _buildLanguagePicker(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 14)),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _resetForm();
                          setState(() => _editing = false);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _readOnlyField('Phone', profile.phone),
                _readOnlyField('Address', profile.address ?? 'Not set'),
                _readOnlyField('Municipality', profile.municipality ?? 'Not set'),
                _readOnlyField('Language', profile.lang == 'ne' ? 'नेपाली' : 'English'),
                const SizedBox(height: 24),

                // Roles section
                Text(
                  'My Roles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...session.roles.map((role) => _roleTile(role, session.activeRole)),

                const SizedBox(height: 32),

                // Sign out
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLanguagePicker() {
    return Row(
      children: [
        _langButton('ne', 'नेपाली'),
        const SizedBox(width: 12),
        _langButton('en', 'English'),
      ],
    );
  }

  Widget _langButton(String lang, String label) {
    final selected = _lang == lang;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _lang = lang),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 2,
            ),
            color: selected ? AppColors.primary.withAlpha(25) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primary : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleTile(
    UserRoleDetails role,
    String activeRole,
  ) {
    final roleName = role.role;
    final isActive = roleName == activeRole;
    final color = _roleColor(roleName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color : AppColors.border,
          width: isActive ? 2 : 1,
        ),
        color: isActive ? color.withAlpha(15) : null,
      ),
      child: Row(
        children: [
          Icon(_roleIcon(roleName), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel(roleName),
                  style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? color : null),
                ),
                if (roleName == 'farmer' && role.farmName != null)
                  Text(role.farmName!, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                if (roleName == 'rider' && role.vehicleType != null)
                  Text(
                    '${_capitalize(role.vehicleType!)} • ${role.vehicleCapacityKg?.toStringAsFixed(0) ?? '?'} kg',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (isActive)
            Icon(Icons.check_circle, color: color, size: 20),
          if (role.verified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified, color: AppColors.secondary, size: 18),
            ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'farmer':
        return AppColors.secondary;
      case 'rider':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'farmer':
        return Icons.agriculture;
      case 'rider':
        return Icons.delivery_dining;
      default:
        return Icons.shopping_bag;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'farmer':
        return 'Farmer';
      case 'rider':
        return 'Rider';
      default:
        return 'Consumer';
    }
  }

  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}
