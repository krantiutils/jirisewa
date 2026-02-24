import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';

class RoleSwitcherBar extends ConsumerWidget {
  const RoleSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeRoleProvider);
    final roles = ref.watch(userRolesProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _roleLabel(activeRole),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _roleColor(activeRole),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showRolePicker(context, ref, activeRole, roles),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Switch',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  Icon(Icons.swap_horiz, size: 14, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRolePicker(
    BuildContext context,
    WidgetRef ref,
    String activeRole,
    List<UserRoleDetails> roles,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch Role',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...['consumer', 'farmer', 'rider'].where((role) {
                  return roles.any((r) => r.role == role);
                }).map((role) {
                  final isActive = role == activeRole;
                  return ListTile(
                    leading: Icon(
                      _roleIcon(role),
                      color: isActive ? _roleColor(role) : Colors.grey[400],
                    ),
                    title: Text(
                      _roleLabel(role),
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? _roleColor(role) : null,
                      ),
                    ),
                    subtitle: Text(_roleDescription(role)),
                    trailing: isActive
                        ? Icon(Icons.check_circle, color: _roleColor(role))
                        : null,
                    onTap: () {
                      ref.read(activeRoleProvider.notifier).switchRole(role);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'rider': return 'Rider';
      case 'farmer': return 'Farmer';
      default: return 'Consumer';
    }
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'rider': return 'Deliver produce along your route';
      case 'farmer': return 'List and sell your produce';
      default: return 'Browse and buy fresh produce';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'rider': return Icons.local_shipping;
      case 'farmer': return Icons.agriculture;
      default: return Icons.shopping_bag;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'rider': return AppColors.accent;
      case 'farmer': return AppColors.secondary;
      default: return AppColors.primary;
    }
  }
}
