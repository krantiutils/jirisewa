import 'package:flutter/material.dart';

import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

/// Compact bar shown above the bottom nav for users with multiple roles.
/// Tapping it opens a bottom sheet to switch the active role.
class RoleSwitcherBar extends StatelessWidget {
  const RoleSwitcherBar({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionProvider.of(context);

    return Material(
      color: _roleColor(session.activeRole).withAlpha(25),
      child: InkWell(
        onTap: () => _showRolePicker(context, session),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _roleIcon(session.activeRole),
                size: 16,
                color: _roleColor(session.activeRole),
              ),
              const SizedBox(width: 6),
              Text(
                _roleLabel(session.activeRole),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _roleColor(session.activeRole),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: _roleColor(session.activeRole),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRolePicker(BuildContext context, SessionService session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Switch Role',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to use JiriSewa',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                ...session.roles.map((role) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RoleTile(
                    role: role.role,
                    isActive: role.role == session.activeRole,
                    onTap: () {
                      session.switchRole(role.role);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String role;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: 2,
          ),
          color: isActive ? color.withAlpha(25) : null,
        ),
        child: Row(
          children: [
            Icon(_roleIcon(role), color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleLabel(role),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isActive ? color : null,
                    ),
                  ),
                  Text(
                    _roleDescription(role),
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? color : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

// -- Shared helpers --

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

String _roleDescription(String role) {
  switch (role) {
    case 'farmer':
      return 'Manage listings and fulfill orders';
    case 'rider':
      return 'Post trips and deliver produce';
    default:
      return 'Browse marketplace and order produce';
  }
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
