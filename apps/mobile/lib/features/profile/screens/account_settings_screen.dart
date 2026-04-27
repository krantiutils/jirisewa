import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jirisewa_mobile/core/providers/auth_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account settings: edit profile fields, view read-only account info,
/// and change password (email users only).
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  // Profile controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Password controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _changingPassword = false;
  String? _error;
  String? _passwordError;
  String? _success;
  bool _populated = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _populate() {
    if (_populated) return;
    final profile = ref.read(userProfileProvider);
    final session = ref.read(currentSessionProvider);
    if (profile != null) {
      _nameController.text = profile.name;
      _phoneController.text =
          profile.phone.isNotEmpty ? profile.phone : (session?.user.phone ?? '');
      _populated = true;
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final profile = ref.read(userProfileProvider);
      if (profile == null) {
        setState(() {
          _saving = false;
          _error = 'No profile found';
        });
        return;
      }

      final client = ref.read(supabaseProvider);

      // Update user_profiles table
      await client
          .from('user_profiles')
          .update({'full_name': name}).eq('id', profile.id);

      // Update users table
      final usersUpdate = <String, dynamic>{
        'name': name,
        'phone': _phoneController.text.trim(),
      };
      await client.from('users').update(usersUpdate).eq('id', profile.id);

      // If farmer role and bio filled, update user_profiles.bio
      final activeRole = ref.read(activeRoleProvider);
      final bio = _bioController.text.trim();
      if (activeRole == 'farmer' && bio.isNotEmpty) {
        await client
            .from('user_profiles')
            .update({'bio': bio}).eq('id', profile.id);
      }

      await ref.read(userSessionProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = 'Profile updated successfully';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      setState(() => _passwordError = 'Current password is required');
      return;
    }
    if (newPassword.length < 6) {
      setState(
          () => _passwordError = 'New password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _passwordError = 'Passwords do not match');
      return;
    }

    setState(() {
      _changingPassword = true;
      _passwordError = null;
      _success = null;
    });

    try {
      final client = ref.read(supabaseProvider);
      final session = ref.read(currentSessionProvider);
      final email = session?.user.email ?? '';

      // Verify current password
      await client.auth
          .signInWithPassword(email: email, password: currentPassword);

      // Update to new password
      await client.auth.updateUser(UserAttributes(password: newPassword));

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _changingPassword = false;
        _success = 'Password changed successfully';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _passwordError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingPassword = false;
        _passwordError = 'Failed to change password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final session = ref.watch(currentSessionProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _populate();

    final email = session?.user.email ?? '';
    final isEmailUser = email.isNotEmpty;
    final createdAt = session?.user.createdAt;
    final memberSince = createdAt != null
        ? DateFormat.yMMMd().format(DateTime.parse(createdAt))
        : 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Profile Section ---
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _label('Full Name'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Your full name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            _label('Phone'),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(hintText: 'Phone number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Bio field (farmer only)
            if (activeRole == 'farmer') ...[
              _label('Bio'),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  hintText: 'Tell customers about your farm...',
                ),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
            ],

            // Error / success messages
            if (_error != null) ...[
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 14)),
              const SizedBox(height: 12),
            ],
            if (_success != null) ...[
              Text(_success!,
                  style: const TextStyle(
                      color: AppColors.secondary, fontSize: 14)),
              const SizedBox(height: 12),
            ],

            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: Text(_saving ? 'Saving...' : 'Save Profile'),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // --- Account Info Section (read-only) ---
            Text(
              'Account Info',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _readOnlyField('Email', email.isNotEmpty ? email : 'Not set'),
            _readOnlyField('Role', _roleLabel(activeRole)),
            _readOnlyField('Member Since', memberSince),

            // --- Password Change Section (email users only) ---
            if (isEmailUser) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Change Password',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              _label('Current Password'),
              TextField(
                controller: _currentPasswordController,
                decoration:
                    const InputDecoration(hintText: 'Enter current password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              _label('New Password'),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                    hintText: 'Enter new password (min 6 chars)'),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              _label('Confirm New Password'),
              TextField(
                controller: _confirmPasswordController,
                decoration:
                    const InputDecoration(hintText: 'Confirm new password'),
                obscureText: true,
              ),

              if (_passwordError != null) ...[
                const SizedBox(height: 12),
                Text(_passwordError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 14)),
              ],

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _changingPassword ? null : _changePassword,
                child: Text(
                    _changingPassword ? 'Changing...' : 'Change Password'),
              ),
            ],

            const SizedBox(height: 32),
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
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
            width: 110,
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
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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
}
