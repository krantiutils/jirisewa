import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../marketplace/screens/marketplace_screen.dart';
import '../../orders/screens/order_list_screen.dart';
import '../../trips/screens/trip_list_screen.dart';
import '../../produce/screens/produce_management_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Role-aware bottom navigation shell.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final roles = auth.roles;

    final tabs = _buildTabs(roles, cart.itemCount);

    // Clamp index if tabs changed (e.g. after profile reload)
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: tabs.map((t) => t.destination).toList(),
      ),
    );
  }

  List<_TabConfig> _buildTabs(Set<UserRole> roles, int cartCount) {
    final tabs = <_TabConfig>[];

    // Home — always first
    tabs.add(_TabConfig(
      screen: const HomeScreen(),
      destination: const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
    ));

    // Marketplace — for consumers (and everyone can browse)
    tabs.add(_TabConfig(
      screen: const MarketplaceScreen(),
      destination: NavigationDestination(
        icon: cartCount > 0
            ? Badge.count(count: cartCount, child: const Icon(Icons.storefront_outlined))
            : const Icon(Icons.storefront_outlined),
        selectedIcon: cartCount > 0
            ? Badge.count(count: cartCount, child: const Icon(Icons.storefront))
            : const Icon(Icons.storefront),
        label: 'Market',
      ),
    ));

    // Trips — for riders
    if (roles.contains(UserRole.rider)) {
      tabs.add(_TabConfig(
        screen: const TripListScreen(),
        destination: const NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Trips',
        ),
      ));
    }

    // My Listings — for farmers
    if (roles.contains(UserRole.farmer)) {
      tabs.add(_TabConfig(
        screen: const ProduceManagementScreen(),
        destination: const NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Listings',
        ),
      ));
    }

    // Orders — for all
    tabs.add(_TabConfig(
      screen: const OrderListScreen(),
      destination: const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
    ));

    // Profile — always last
    tabs.add(_TabConfig(
      screen: const ProfileScreen(),
      destination: const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ));

    return tabs;
  }
}

class _TabConfig {
  final Widget screen;
  final NavigationDestination destination;

  const _TabConfig({required this.screen, required this.destination});
}
