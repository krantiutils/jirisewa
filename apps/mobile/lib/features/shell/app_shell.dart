import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/shell/role_switcher.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeRoleProvider);
    final hasMultiple = ref.watch(hasMultipleRolesProvider);
    final isRider = activeRole == 'rider';

    final branchMap = isRider
        ? [ShellBranch.home, ShellBranch.trips, ShellBranch.orders, ShellBranch.profile]
        : [ShellBranch.home, ShellBranch.marketplace, ShellBranch.orders, ShellBranch.profile];

    final currentBranch = navigationShell.currentIndex;
    int displayIndex = branchMap.indexOf(currentBranch);
    if (displayIndex < 0) {
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
          if (hasMultiple) const RoleSwitcherBar(),
          BottomNavigationBar(
            currentIndex: displayIndex,
            onTap: (index) => navigationShell.goBranch(
              branchMap[index],
              initialLocation: index == displayIndex,
            ),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: _tabColor(activeRole),
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
