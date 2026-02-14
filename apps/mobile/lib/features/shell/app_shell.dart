import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/shell/role_switcher.dart';

/// App shell with role-aware bottom tab navigation.
///
/// Consumer/Farmer tabs: Home, Marketplace, Orders, Profile
/// Rider tabs:           Home, Trips, Orders, Profile
///
/// The shell wraps a [StatefulNavigationShell] with 5 branches.
/// Only 4 are shown at a time — the second tab swaps between
/// Marketplace (branch 1) and Trips (branch 2) based on active role.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final session = SessionProvider.of(context);
    final isRider = session.isRider;

    // Map from displayed tab index (0-3) to shell branch index (0-4).
    final branchMap = isRider
        ? [ShellBranch.home, ShellBranch.trips, ShellBranch.orders, ShellBranch.profile]
        : [ShellBranch.home, ShellBranch.marketplace, ShellBranch.orders, ShellBranch.profile];

    // Reverse map: shell branch index → displayed tab index.
    final currentBranch = navigationShell.currentIndex;
    int displayIndex = branchMap.indexOf(currentBranch);
    if (displayIndex < 0) {
      // User switched role while on a tab that doesn't exist in new role.
      // Fall back to home.
      displayIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigationShell.goBranch(ShellBranch.home);
      });
    }

    final items = isRider
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.route_outlined), activeIcon: Icon(Icons.route), label: 'Trips'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront), label: 'Marketplace'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
          ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.hasMultipleRoles)
            const RoleSwitcherBar(),
          BottomNavigationBar(
            currentIndex: displayIndex,
            onTap: (index) => navigationShell.goBranch(
              branchMap[index],
              initialLocation: index == displayIndex,
            ),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _tabColor(session.activeRole),
            unselectedItemColor: Colors.grey[500],
            backgroundColor: AppColors.background,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: items,
          ),
        ],
      ),
    );
  }

  Color _tabColor(String role) {
    switch (role) {
      case 'rider':
        return AppColors.accent;
      case 'farmer':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }
}
