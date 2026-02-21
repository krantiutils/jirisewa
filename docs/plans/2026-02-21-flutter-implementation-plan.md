# Flutter App Full Build-Out Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the JiriSewa Flutter mobile app to full feature parity with the web app, migrating to Riverpod state management.

**Architecture:** Feature-first Riverpod with repositories wrapping Supabase calls. Each feature module has co-located providers, repositories, models, screens, and widgets. GoRouter integrated with Riverpod for auth-driven navigation.

**Tech Stack:** Flutter 3.11+, Riverpod 2.6, GoRouter 15, Supabase Flutter 2.8, flutter_map 8, Firebase Messaging 15, SharedPreferences, url_launcher, webview_flutter, image_picker, cached_network_image, fl_chart

---

## Phase 0: Riverpod Setup + Core Providers + Migrate Existing Screens

### Task 0.1: Add Riverpod Dependencies

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/analysis_options.yaml`

**Step 1: Update pubspec.yaml**

Add to `dependencies:` section:
```yaml
  flutter_riverpod: ^2.6.1
  shared_preferences: ^2.3.0
  cached_network_image: ^3.4.1
  url_launcher: ^6.3.0
  image_picker: ^1.1.2
  intl: ^0.20.0
```

Add to `dev_dependencies:` section:
```yaml
  riverpod_generator: ^2.6.3
  build_runner: ^2.4.13
  riverpod_lint: ^2.6.3
  custom_lint: ^0.7.0
```

**Step 2: Update analysis_options.yaml**

Add custom_lint plugin:
```yaml
analyzer:
  plugins:
    - custom_lint
```

**Step 3: Install dependencies**

Run: `cd apps/mobile && flutter pub get`
Expected: All dependencies resolve successfully.

**Step 4: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/analysis_options.yaml
git commit -m "chore: add Riverpod and new dependencies"
```

---

### Task 0.2: Create Core Supabase + Auth Providers

**Files:**
- Create: `apps/mobile/lib/core/providers/supabase_provider.dart`
- Create: `apps/mobile/lib/core/providers/auth_provider.dart`
- Create: `apps/mobile/lib/core/providers/session_provider.dart`

**Step 1: Create Supabase provider**

File: `apps/mobile/lib/core/providers/supabase_provider.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

**Step 2: Create auth state provider**

File: `apps/mobile/lib/core/providers/auth_provider.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

/// Streams Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.read(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// Current session, derived from auth state stream.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session;
});

/// Whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});
```

**Step 3: Create session/profile provider**

File: `apps/mobile/lib/core/providers/session_provider.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/providers/auth_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

/// User profile + roles, auto-fetched when authenticated.
class UserSession {
  final UserProfile? profile;
  final List<UserRoleDetails> roles;

  const UserSession({this.profile, this.roles = const []});

  bool get hasProfile => profile != null;
  bool get hasMultipleRoles => roles.length > 1;
}

final userSessionProvider =
    AsyncNotifierProvider<UserSessionNotifier, UserSession>(
  UserSessionNotifier.new,
);

class UserSessionNotifier extends AsyncNotifier<UserSession> {
  @override
  Future<UserSession> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const UserSession();

    final client = ref.read(supabaseProvider);
    final userId = session.user.id;

    final profileResponse = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profileResponse == null) {
      return const UserSession();
    }

    final profile = UserProfile.fromMap(profileResponse);

    final rolesResponse =
        await client.from('user_roles').select().eq('user_id', userId);

    final roles = (rolesResponse as List)
        .map((r) => UserRoleDetails.fromMap(r as Map<String, dynamic>))
        .toList();

    return UserSession(profile: profile, roles: roles);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Active role state (consumer/rider/farmer).
final activeRoleProvider =
    NotifierProvider<ActiveRoleNotifier, String>(ActiveRoleNotifier.new);

class ActiveRoleNotifier extends Notifier<String> {
  @override
  String build() {
    final session = ref.watch(userSessionProvider).valueOrNull;
    if (session == null || session.profile == null) return 'consumer';

    final roles = session.roles;
    final primaryRole = session.profile!.role;

    if (roles.isNotEmpty) {
      final hasRole = roles.any((r) => r.role == primaryRole);
      return hasRole ? primaryRole : roles.first.role;
    }
    return primaryRole;
  }

  void switchRole(String role) {
    final session = ref.read(userSessionProvider).valueOrNull;
    if (session == null) return;
    if (session.roles.any((r) => r.role == role)) {
      state = role;
    }
  }
}

/// Convenience providers.
final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.profile;
});

final userRolesProvider = Provider<List<UserRoleDetails>>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.roles ?? const [];
});

final isRiderProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'rider';
});

final isFarmerProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'farmer';
});

final isConsumerProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'consumer';
});

final hasMultipleRolesProvider = Provider<bool>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.hasMultipleRoles ?? false;
});

final hasProfileProvider = Provider<bool>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.hasProfile ?? false;
});
```

**Step 4: Run analyze**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos`
Expected: No errors.

**Step 5: Commit**

```bash
git add apps/mobile/lib/core/providers/
git commit -m "feat: add core Riverpod providers (supabase, auth, session)"
```

---

### Task 0.3: Wrap App in ProviderScope + Update main.dart

**Files:**
- Modify: `apps/mobile/lib/main.dart`

**Step 1: Update main.dart**

Replace the entire file:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/push_notification_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    ),
  );

  await PushNotificationService.instance.initialize();

  runApp(const ProviderScope(child: JiriSewaApp()));
}

class JiriSewaApp extends ConsumerWidget {
  const JiriSewaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'JiriSewa',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

**Step 2: Update app_router.dart to use Riverpod**

Replace the entire file `apps/mobile/lib/core/routing/app_router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/providers/auth_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';
import 'package:jirisewa_mobile/features/auth/screens/register_screen.dart';
import 'package:jirisewa_mobile/features/home/screens/home_screen.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/marketplace_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/orders_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_detail_screen.dart';
import 'package:jirisewa_mobile/features/profile/screens/profile_screen.dart';
import 'package:jirisewa_mobile/features/shell/app_shell.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const marketplace = '/marketplace';
  static const trips = '/trips';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const profile = '/profile';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const chat = '/chat';
  static const chatDetail = '/chat/:conversationId';
  static const notifications = '/notifications';
  static const notificationPreferences = '/notifications/preferences';
  static const produceDetail = '/produce/:id';
  static const tripNew = '/trips/new';
  static const tripDetail = '/trips/:id';
  static const tripPlan = '/trips/:id/plan';
  static const orderTracking = '/orders/:id/tracking';
  static const farmerListingNew = '/farmer/listings/new';
  static const farmerListingEdit = '/farmer/listings/:id/edit';
  static const farmerAnalytics = '/farmer/analytics';
  static const farmerVerification = '/farmer/verification';
  static const farmerSubscriptions = '/farmer/subscriptions';
  static const farmerBulkOrders = '/farmer/bulk-orders';
  static const subscriptions = '/subscriptions';
  static const businessRegister = '/business/register';
  static const businessDashboard = '/business/dashboard';
  static const businessOrders = '/business/orders';
  static const businessOrderDetail = '/business/orders/:id';
}

abstract final class ShellBranch {
  static const home = 0;
  static const marketplace = 1;
  static const trips = 2;
  static const orders = 3;
  static const profile = 4;
}

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final hasProfile = ref.watch(hasProfileProvider);
  final sessionLoading = ref.watch(userSessionProvider).isLoading;

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      if (sessionLoading) return null;

      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnRegister = state.matchedLocation == AppRoutes.register;
      final isAuthRoute = isOnLogin || isOnRegister;

      if (!isAuthenticated) {
        return isOnLogin ? null : AppRoutes.login;
      }

      if (!hasProfile) {
        return isOnRegister ? null : AppRoutes.register;
      }

      if (isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trips,
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final orderId = state.pathParameters['id']!;
                      return OrderDetailScreen(orderId: orderId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
```

**Step 3: Run analyze**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos`
Expected: No errors. There will be warnings about unused SessionService imports in screens — that's expected and will be cleaned up in migration tasks.

**Step 4: Commit**

```bash
git add apps/mobile/lib/main.dart apps/mobile/lib/core/routing/app_router.dart
git commit -m "feat: wrap app in ProviderScope, integrate GoRouter with Riverpod"
```

---

### Task 0.4: Migrate AppShell + RoleSwitcher to Riverpod

**Files:**
- Modify: `apps/mobile/lib/features/shell/app_shell.dart`
- Modify: `apps/mobile/lib/features/shell/role_switcher.dart`

**Step 1: Update app_shell.dart**

Replace the file to use `ConsumerWidget` and read from Riverpod providers instead of `SessionProvider.of(context)`:

```dart
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
```

**Step 2: Update role_switcher.dart**

Replace the file to use `ConsumerWidget`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    List<dynamic> roles,
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
                  return roles.any((r) => (r as dynamic).role == role);
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
```

**Step 3: Run analyze**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos`
Expected: No errors from shell files. Other screens may still reference old SessionProvider.

**Step 4: Commit**

```bash
git add apps/mobile/lib/features/shell/
git commit -m "feat: migrate AppShell and RoleSwitcher to Riverpod"
```

---

### Task 0.5: Migrate Auth Screens to Riverpod

**Files:**
- Modify: `apps/mobile/lib/features/auth/screens/login_screen.dart`
- Modify: `apps/mobile/lib/features/auth/screens/register_screen.dart`

**Step 1: Update login_screen.dart**

Change `StatefulWidget` to `ConsumerStatefulWidget`. Replace `Supabase.instance.client` with `ref.read(supabaseProvider)`. Remove old SessionProvider dependencies. The GoRouter redirect (now driven by Riverpod providers) handles post-login navigation automatically.

Key changes:
- `class _LoginScreenState extends ConsumerState<LoginScreen>`
- `SupabaseClient get _supabase => ref.read(supabaseProvider);`
- Remove any `SessionProvider.of(context)` references

**Step 2: Update register_screen.dart**

Same pattern — `ConsumerStatefulWidget`. For the profile refresh after registration, call:
```dart
ref.read(userSessionProvider.notifier).refresh();
```
instead of `session.refreshProfile()`.

**Step 3: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/auth/
git commit -m "feat: migrate auth screens to Riverpod"
```

---

### Task 0.6: Migrate HomeScreen to Riverpod

**Files:**
- Create: `apps/mobile/lib/features/home/providers/home_provider.dart`
- Modify: `apps/mobile/lib/features/home/screens/home_screen.dart`

**Step 1: Create home provider**

File: `apps/mobile/lib/features/home/providers/home_provider.dart`

Create an `AsyncNotifierProvider` that fetches role-specific dashboard data:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

class HomeDashboardData {
  // Consumer
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> nearbyProduce;
  // Rider
  final List<Map<String, dynamic>> upcomingTrips;
  final List<Map<String, dynamic>> matchedOrders;
  // Farmer
  final List<Map<String, dynamic>> activeListings;
  final List<Map<String, dynamic>> pendingOrders;

  const HomeDashboardData({
    this.recentOrders = const [],
    this.nearbyProduce = const [],
    this.upcomingTrips = const [],
    this.matchedOrders = const [],
    this.activeListings = const [],
    this.pendingOrders = const [],
  });
}

final homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboardData>((ref) async {
  final client = ref.read(supabaseProvider);
  final profile = ref.watch(userProfileProvider);
  final role = ref.watch(activeRoleProvider);

  if (profile == null) return const HomeDashboardData();

  final userId = profile.id;

  switch (role) {
    case 'consumer':
      final orders = await client
          .from('orders')
          .select('id, status, total_price, delivery_fee, created_at')
          .eq('consumer_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      final produce = await client
          .from('produce_listings')
          .select('id, name_en, name_ne, price_per_kg, available_qty_kg, photos')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(6);
      return HomeDashboardData(
        recentOrders: List<Map<String, dynamic>>.from(orders),
        nearbyProduce: List<Map<String, dynamic>>.from(produce),
      );

    case 'rider':
      final trips = await client
          .from('rider_trips')
          .select('id, origin_name, destination_name, departure_at, status, remaining_capacity_kg')
          .eq('rider_id', userId)
          .inFilter('status', ['scheduled', 'in_transit'])
          .order('departure_at')
          .limit(5);
      final orders = await client
          .from('orders')
          .select('id, status, total_price, delivery_fee, delivery_address, created_at')
          .eq('rider_id', userId)
          .inFilter('status', ['matched', 'picked_up', 'in_transit'])
          .order('created_at', ascending: false)
          .limit(5);
      return HomeDashboardData(
        upcomingTrips: List<Map<String, dynamic>>.from(trips),
        matchedOrders: List<Map<String, dynamic>>.from(orders),
      );

    case 'farmer':
      final listings = await client
          .from('produce_listings')
          .select('id, name_en, name_ne, price_per_kg, available_qty_kg')
          .eq('farmer_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);
      final pendingItems = await client
          .from('order_items')
          .select('id, quantity_kg, price_per_kg, subtotal, pickup_confirmed, order_id')
          .eq('farmer_id', userId)
          .eq('pickup_confirmed', false)
          .limit(5);
      return HomeDashboardData(
        activeListings: List<Map<String, dynamic>>.from(listings),
        pendingOrders: List<Map<String, dynamic>>.from(pendingItems),
      );

    default:
      return const HomeDashboardData();
  }
});
```

**Step 2: Update home_screen.dart**

Convert to `ConsumerWidget`. Replace all `setState` + `_loading`/`_error` with `ref.watch(homeDashboardProvider)` using `.when(data:, error:, loading:)`. Remove `didChangeDependencies()` data loading. Use `ref.refresh(homeDashboardProvider)` for pull-to-refresh.

**Step 3: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/home/
git commit -m "feat: migrate HomeScreen to Riverpod with HomeDashboardProvider"
```

---

### Task 0.7: Migrate MarketplaceScreen to Riverpod

**Files:**
- Create: `apps/mobile/lib/features/marketplace/providers/marketplace_provider.dart`
- Create: `apps/mobile/lib/features/marketplace/repositories/produce_repository.dart`
- Modify: `apps/mobile/lib/features/marketplace/screens/marketplace_screen.dart`

**Step 1: Create ProduceRepository**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProduceRepository {
  final SupabaseClient _client;
  ProduceRepository(this._client);

  Future<List<Map<String, dynamic>>> listActiveListings({int limit = 30}) async {
    final result = await _client
        .from('produce_listings')
        .select('id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality, created_at')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> listFarmerListings(String farmerId, {int limit = 20}) async {
    final result = await _client
        .from('produce_listings')
        .select('id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality, created_at')
        .eq('farmer_id', farmerId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<Map<String, dynamic>>> listPendingPickups(String farmerId, {int limit = 20}) async {
    final result = await _client
        .from('order_items')
        .select('id, order_id, listing_id, quantity_kg, subtotal, pickup_confirmed')
        .eq('farmer_id', farmerId)
        .eq('pickup_confirmed', false)
        .order('id')
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, Map<String, dynamic>>> fetchOrdersForIds(List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final result = await _client
        .from('orders')
        .select('id, status, delivery_address, rider_id, rider_trip_id')
        .inFilter('id', orderIds);
    final map = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(result)) {
      final id = row['id'] as String?;
      if (id != null) map[id] = row;
    }
    return map;
  }
}
```

**Step 2: Create marketplace provider**

Wire the repository into a Riverpod provider. Create `FutureProvider.autoDispose` for listings data.

**Step 3: Migrate MarketplaceScreen to ConsumerStatefulWidget**

Replace `_maybeSession()` with `ref.watch(activeRoleProvider)` and `ref.watch(userProfileProvider)`. Replace data loading with provider watches.

**Step 4: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/marketplace/
git commit -m "feat: migrate MarketplaceScreen to Riverpod with ProduceRepository"
```

---

### Task 0.8: Migrate OrdersScreen + OrderDetailScreen to Riverpod

**Files:**
- Create: `apps/mobile/lib/features/orders/providers/orders_provider.dart`
- Create: `apps/mobile/lib/features/orders/repositories/order_repository.dart`
- Modify: `apps/mobile/lib/features/orders/screens/orders_screen.dart`
- Modify: `apps/mobile/lib/features/orders/screens/order_detail_screen.dart`

**Step 1: Create OrderRepository** wrapping all order Supabase queries (listOrders, getOrder, listOrderItems, subscribe to rider location).

**Step 2: Create orders provider** with `FutureProvider.family` taking a status filter.

**Step 3: Migrate both screens** to ConsumerStatefulWidget/ConsumerWidget pattern.

**Step 4: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/orders/
git commit -m "feat: migrate Orders screens to Riverpod with OrderRepository"
```

---

### Task 0.9: Migrate TripsScreen to Riverpod

**Files:**
- Create: `apps/mobile/lib/features/trips/providers/trips_provider.dart`
- Create: `apps/mobile/lib/features/trips/providers/pings_provider.dart`
- Create: `apps/mobile/lib/features/trips/repositories/trip_repository.dart`
- Modify: `apps/mobile/lib/features/trips/screens/trips_screen.dart`

**Step 1: Create TripRepository** wrapping trip queries, ping accept/decline RPCs, and OSRM route recalculation.

**Step 2: Create trips provider** for trip list data.

**Step 3: Create pings provider** as `StreamProvider` wrapping Supabase realtime subscription on `order_pings`.

**Step 4: Migrate TripsScreen** to `ConsumerStatefulWidget`. Replace `_subscribeToPings` with `ref.watch(pingsProvider)`.

**Step 5: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/trips/
git commit -m "feat: migrate TripsScreen to Riverpod with realtime pings"
```

---

### Task 0.10: Migrate ProfileScreen + Tracking to Riverpod

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart`
- Modify: `apps/mobile/lib/features/tracking/screens/trip_tracking_screen.dart`

**Step 1: Migrate ProfileScreen** — read profile from `ref.watch(userProfileProvider)`, role from `ref.watch(activeRoleProvider)`. Profile updates call `ref.read(userSessionProvider.notifier).refresh()`.

**Step 2: Migrate TripTrackingScreen** — keep `LocationTrackingService` as-is (it's a standalone service), but read Supabase client from provider.

**Step 3: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/profile/ apps/mobile/lib/features/tracking/
git commit -m "feat: migrate Profile and Tracking screens to Riverpod"
```

---

### Task 0.11: Remove Old SessionService

**Files:**
- Delete: `apps/mobile/lib/core/services/session_service.dart`
- Verify: No remaining imports of `session_service.dart` in any file

**Step 1: Remove old session_service.dart**

Delete the file. Grep the codebase for any remaining `import.*session_service` or `SessionProvider.of` references and fix them.

**Step 2: Run full analyze + test**

Run: `cd apps/mobile && flutter analyze --no-fatal-infos && flutter test`
Expected: All pass. No references to old SessionService.

**Step 3: Commit**

```bash
git add -A apps/mobile/
git commit -m "refactor: remove legacy SessionService, complete Riverpod migration"
```

---

## Phase 1: Cart + Checkout + Payments

### Task 1.1: Cart Provider + Model

**Files:**
- Create: `apps/mobile/lib/features/cart/models/cart.dart`
- Create: `apps/mobile/lib/features/cart/providers/cart_provider.dart`

**Step 1: Create Cart model**

```dart
import 'dart:convert';

class CartItem {
  final String listingId;
  final String farmerId;
  final double quantityKg;
  final double pricePerKg;
  final String nameEn;
  final String? nameNe;
  final String farmerName;
  final String? photo;

  const CartItem({
    required this.listingId,
    required this.farmerId,
    required this.quantityKg,
    required this.pricePerKg,
    required this.nameEn,
    this.nameNe,
    required this.farmerName,
    this.photo,
  });

  double get subtotal => quantityKg * pricePerKg;

  CartItem copyWith({double? quantityKg}) {
    return CartItem(
      listingId: listingId,
      farmerId: farmerId,
      quantityKg: quantityKg ?? this.quantityKg,
      pricePerKg: pricePerKg,
      nameEn: nameEn,
      nameNe: nameNe,
      farmerName: farmerName,
      photo: photo,
    );
  }

  Map<String, dynamic> toJson() => {
    'listingId': listingId,
    'farmerId': farmerId,
    'quantityKg': quantityKg,
    'pricePerKg': pricePerKg,
    'nameEn': nameEn,
    'nameNe': nameNe,
    'farmerName': farmerName,
    'photo': photo,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    listingId: json['listingId'] as String,
    farmerId: json['farmerId'] as String,
    quantityKg: (json['quantityKg'] as num).toDouble(),
    pricePerKg: (json['pricePerKg'] as num).toDouble(),
    nameEn: json['nameEn'] as String,
    nameNe: json['nameNe'] as String?,
    farmerName: json['farmerName'] as String,
    photo: json['photo'] as String?,
  );
}

class Cart {
  final List<CartItem> items;
  const Cart({this.items = const []});

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalKg => items.fold(0, (sum, item) => sum + item.quantityKg);
  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;

  /// Group items by farmerId.
  Map<String, List<CartItem>> get byFarmer {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.farmerId, () => []).add(item);
    }
    return map;
  }

  String toJsonString() => json.encode(items.map((i) => i.toJson()).toList());

  factory Cart.fromJsonString(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return Cart(
      items: list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
```

**Step 2: Create CartNotifier provider backed by SharedPreferences**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jirisewa_mobile/features/cart/models/cart.dart';

const _cartKey = 'jirisewa_cart';

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() {
    _loadFromStorage();
    return const Cart();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson != null && cartJson.isNotEmpty) {
      state = Cart.fromJsonString(cartJson);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, state.toJsonString());
  }

  void addItem(CartItem item) {
    final existing = state.items.indexWhere((i) => i.listingId == item.listingId);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantityKg: updated[existing].quantityKg + item.quantityKg,
      );
      state = Cart(items: updated);
    } else {
      state = Cart(items: [...state.items, item]);
    }
    _persist();
  }

  void updateQuantity(String listingId, double quantityKg) {
    final updated = state.items.map((item) {
      if (item.listingId == listingId) {
        return item.copyWith(quantityKg: quantityKg);
      }
      return item;
    }).toList();
    state = Cart(items: updated);
    _persist();
  }

  void removeItem(String listingId) {
    state = Cart(items: state.items.where((i) => i.listingId != listingId).toList());
    _persist();
  }

  void clear() {
    state = const Cart();
    _persist();
  }
}
```

**Step 3: Run analyze + commit**

```bash
cd apps/mobile && flutter analyze --no-fatal-infos
git add apps/mobile/lib/features/cart/
git commit -m "feat: add Cart model and CartNotifier with SharedPreferences persistence"
```

---

### Task 1.2: Cart Screen

**Files:**
- Create: `apps/mobile/lib/features/cart/screens/cart_screen.dart`
- Create: `apps/mobile/lib/features/cart/widgets/cart_badge.dart`
- Modify: `apps/mobile/lib/core/routing/app_router.dart` (add cart route)

Build the CartScreen as a `ConsumerWidget` showing items grouped by farmer, quantity adjustment, remove buttons, subtotal per farmer, and grand total. Add a "Proceed to Checkout" button.

Create CartBadge widget showing item count on cart icon (for use in AppShell header).

Add `/cart` route to GoRouter.

**Commit:** `feat: add CartScreen and CartBadge`

---

### Task 1.3: Checkout Screen + Delivery Fee

**Files:**
- Create: `apps/mobile/lib/features/checkout/screens/checkout_screen.dart`
- Create: `apps/mobile/lib/features/checkout/providers/checkout_provider.dart`
- Create: `apps/mobile/lib/features/checkout/providers/delivery_fee_provider.dart`

Multi-step checkout:
1. Location picker (reuse existing `LocationPickerWidget`)
2. Payment method selection (cash/esewa/khalti/connectips)
3. Review with delivery fee breakdown
4. Confirm + place order

Delivery fee provider calls OSRM for distance, computes: base_fee + (distance_km * per_km_rate) + (weight_kg * per_kg_rate).

**Commit:** `feat: add Checkout flow with delivery fee calculation`

---

### Task 1.4: Place Order Action

**Files:**
- Modify: `apps/mobile/lib/features/orders/repositories/order_repository.dart`

Add `placeOrder()` method that:
1. Creates order in `orders` table
2. Creates `order_items` rows
3. Creates `farmer_payouts` rows
4. For digital payments: creates transaction record in `esewa_transactions` / `khalti_transactions` / `connectips_transactions`
5. Returns order ID + payment redirect data

**Commit:** `feat: add placeOrder to OrderRepository`

---

### Task 1.5: Payment Gateway Integration

**Files:**
- Create: `apps/mobile/lib/features/payments/services/esewa_service.dart`
- Create: `apps/mobile/lib/features/payments/services/khalti_service.dart`
- Create: `apps/mobile/lib/features/payments/services/connectips_service.dart`
- Create: `apps/mobile/lib/features/payments/providers/payment_provider.dart`

eSewa: Generate HMAC-SHA256 signed message, build form params, launch via `url_launcher`.
Khalti: Call Khalti initiation API, get payment URL, launch via `url_launcher`.
connectIPS: Build RSA-signed form, POST via `webview_flutter`.

Deep link setup in Android manifest + iOS Info.plist for payment callbacks.

**Commit:** `feat: add payment gateway services (eSewa, Khalti, connectIPS)`

---

### Task 1.6: Produce Detail Screen

**Files:**
- Create: `apps/mobile/lib/features/marketplace/screens/produce_detail_screen.dart`
- Create: `apps/mobile/lib/features/marketplace/providers/produce_detail_provider.dart`

Full produce detail: photo carousel, name, price, available quantity, farmer info (name, rating), "Add to Cart" button with quantity selector. Add route `/produce/:id`.

**Commit:** `feat: add ProduceDetailScreen with add-to-cart`

---

## Phase 2: Trip Creation + Route Planning

### Task 2.1: Trip Creation Screen (4-step)

**Files:**
- Create: `apps/mobile/lib/features/trips/screens/trip_creation_screen.dart`
- Create: `apps/mobile/lib/features/trips/providers/trip_creation_provider.dart`

4-step form:
1. Origin (MunicipalityPicker + LocationPicker)
2. Destination (MunicipalityPicker + LocationPicker)
3. Details (departure datetime, capacity kg)
4. Review (OSRM route preview on map, confirm)

Trip creation calls `TripRepository.createTrip()` which inserts into `rider_trips` with PostGIS geography.

Add route `/trips/new`.

**Commit:** `feat: add 4-step TripCreationScreen`

---

### Task 2.2: Trip Detail Screen

**Files:**
- Create: `apps/mobile/lib/features/trips/screens/trip_detail_screen.dart`
- Create: `apps/mobile/lib/features/trips/providers/trip_detail_provider.dart`

Shows: route map, matched orders, trip stops with sequence. Actions: start trip, per-farmer pickup confirmation, mark items unavailable, start delivery, complete trip, cancel trip.

Add route `/trips/:id`.

**Commit:** `feat: add TripDetailScreen with order management`

---

### Task 2.3: Route Planning Screen

**Files:**
- Create: `apps/mobile/lib/features/trips/screens/route_plan_screen.dart`

OSRM-optimized stop ordering. Shows all stops on map with sequence numbers. "Optimize Route" button calls `optimizeTripRoute` RPC. Manual drag-to-reorder.

Add route `/trips/:id/plan`.

**Commit:** `feat: add RoutePlanScreen with OSRM optimization`

---

## Phase 3: Chat + Notifications

### Task 3.1: Chat Repository + Providers

**Files:**
- Create: `apps/mobile/lib/features/chat/repositories/chat_repository.dart`
- Create: `apps/mobile/lib/features/chat/providers/chat_provider.dart`
- Create: `apps/mobile/lib/features/chat/models/conversation.dart`
- Create: `apps/mobile/lib/features/chat/models/chat_message.dart`

ChatRepository wraps: getOrCreateConversation, sendMessage, listConversations, getMessages, markConversationRead, uploadChatImage, getTotalUnreadCount.

Providers:
- `conversationsProvider` — FutureProvider for conversation list
- `messagesProvider` — StreamProvider.family for realtime messages per conversation
- `unreadChatCountProvider` — FutureProvider for total unread

**Commit:** `feat: add Chat repository, models, and providers`

---

### Task 3.2: Conversations Screen

**Files:**
- Create: `apps/mobile/lib/features/chat/screens/conversations_screen.dart`

List of conversations with last message preview, unread badge, participant avatars. Tap navigates to ChatScreen. Add route `/chat`.

**Commit:** `feat: add ConversationsScreen`

---

### Task 3.3: Chat Screen

**Files:**
- Create: `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- Create: `apps/mobile/lib/features/chat/widgets/message_bubble.dart`

Realtime message list. Text input + image upload button + location share button. Auto-scroll to bottom. Marks conversation read on open. Supabase realtime subscription for new messages.

Add route `/chat/:conversationId`.

**Commit:** `feat: add ChatScreen with realtime messages`

---

### Task 3.4: Chat Badge + Order Chat Button

**Files:**
- Create: `apps/mobile/lib/features/chat/widgets/chat_badge.dart`
- Create: `apps/mobile/lib/features/chat/widgets/order_chat_button.dart`

ChatBadge: Icon button with unread count badge for AppShell header.
OrderChatButton: Button on OrderDetailScreen to open/create chat for that order.

**Commit:** `feat: add ChatBadge and OrderChatButton`

---

### Task 3.5: Notification Repository + Providers

**Files:**
- Create: `apps/mobile/lib/features/notifications/repositories/notification_repository.dart`
- Create: `apps/mobile/lib/features/notifications/providers/notification_provider.dart`
- Create: `apps/mobile/lib/features/notifications/models/app_notification.dart`

Repository wraps: listNotifications, getUnreadCount, markRead, markAllRead, getPreferences, updatePreference.

**Commit:** `feat: add Notification repository and providers`

---

### Task 3.6: Notifications Screen

**Files:**
- Create: `apps/mobile/lib/features/notifications/screens/notifications_screen.dart`

Paginated notification list. Tap marks as read + navigates to relevant screen (based on `data.url`). "Mark all read" button. Add route `/notifications`.

**Commit:** `feat: add NotificationsScreen`

---

### Task 3.7: Notification Preferences Screen

**Files:**
- Create: `apps/mobile/lib/features/notifications/screens/notification_preferences_screen.dart`

Toggle per notification category. Reads/writes `notification_preferences` table. Add route `/notifications/preferences`.

**Commit:** `feat: add NotificationPreferencesScreen`

---

### Task 3.8: Notification Bell Widget

**Files:**
- Create: `apps/mobile/lib/features/notifications/widgets/notification_bell.dart`

Icon button with unread count badge. Add to AppShell header alongside ChatBadge.

**Commit:** `feat: add NotificationBell widget`

---

## Phase 4: Ratings + Farmer Tools

### Task 4.1: Rating System

**Files:**
- Create: `apps/mobile/lib/features/ratings/repositories/rating_repository.dart`
- Create: `apps/mobile/lib/features/ratings/providers/rating_provider.dart`
- Create: `apps/mobile/lib/features/ratings/widgets/rating_modal.dart`
- Create: `apps/mobile/lib/features/ratings/widgets/star_rating.dart`
- Create: `apps/mobile/lib/features/ratings/widgets/rating_badge.dart`
- Create: `apps/mobile/lib/features/ratings/widgets/ratings_list.dart`

RatingRepository: submitRating, getOrderRatingStatus, getUserRatings.
RatingModal: Bottom sheet with star selector + comment, validates delivered order.
StarRating: Interactive 1-5 star widget.
RatingBadge: Shows average + count.
RatingsList: Paginated list of received ratings.

**Commit:** `feat: add rating system (modal, star rating, badges, list)`

---

### Task 4.2: Farmer Listing Creation/Edit

**Files:**
- Create: `apps/mobile/lib/features/farmer/screens/create_listing_screen.dart`
- Create: `apps/mobile/lib/features/farmer/screens/edit_listing_screen.dart`
- Create: `apps/mobile/lib/features/farmer/repositories/farmer_repository.dart`
- Create: `apps/mobile/lib/features/farmer/providers/farmer_provider.dart`

Form with: category selector, name (en/ne), price/kg, available quantity, freshness date, photos (image_picker + Supabase Storage upload), location picker.

FarmerRepository: createListing, updateListing, getCategories, uploadPhoto.

Add routes `/farmer/listings/new` and `/farmer/listings/:id/edit`.

**Commit:** `feat: add farmer listing creation and editing`

---

### Task 4.3: Farmer Analytics Screen

**Files:**
- Create: `apps/mobile/lib/features/farmer/screens/analytics_screen.dart`
- Create: `apps/mobile/lib/features/farmer/providers/analytics_provider.dart`

Charts using `fl_chart`:
- Revenue trend (line chart)
- Sales by category (pie chart)
- Top products (bar chart)
- Price benchmarks (comparison bars)
- Fulfillment rate (gauge/percentage)
- Rating distribution (bar chart)

Data via Supabase RPC functions: `farmer_revenue_trend`, `farmer_sales_by_category`, `farmer_top_products`, `farmer_price_benchmarks`, `farmer_fulfillment_rate`, `farmer_rating_distribution`.

Add route `/farmer/analytics`.

**Commit:** `feat: add FarmerAnalyticsScreen with charts`

---

### Task 4.4: Farmer Verification Screen

**Files:**
- Create: `apps/mobile/lib/features/farmer/screens/verification_screen.dart`

Upload citizenship photo, farm photo, municipality letter (via image_picker + Supabase Storage). Shows current verification status and admin notes if rejected.

Add route `/farmer/verification`.

**Commit:** `feat: add FarmerVerificationScreen`

---

## Phase 5: Subscriptions + Business/B2B

### Task 5.1: Subscription System

**Files:**
- Create: `apps/mobile/lib/features/subscriptions/repositories/subscription_repository.dart`
- Create: `apps/mobile/lib/features/subscriptions/providers/subscription_provider.dart`
- Create: `apps/mobile/lib/features/subscriptions/screens/subscription_browse_screen.dart`
- Create: `apps/mobile/lib/features/subscriptions/screens/farmer_subscriptions_screen.dart`
- Create: `apps/mobile/lib/features/subscriptions/models/subscription_plan.dart`

Consumer: Browse plans, subscribe with payment method, manage (pause/resume/cancel).
Farmer: Create plans (name, price, frequency, items, max subscribers), toggle active.

Add routes `/subscriptions` and `/farmer/subscriptions`.

**Commit:** `feat: add subscription system (browse, manage, farmer plans)`

---

### Task 5.2: Business/B2B System

**Files:**
- Create: `apps/mobile/lib/features/business/repositories/business_repository.dart`
- Create: `apps/mobile/lib/features/business/providers/business_provider.dart`
- Create: `apps/mobile/lib/features/business/screens/business_register_screen.dart`
- Create: `apps/mobile/lib/features/business/screens/business_dashboard_screen.dart`
- Create: `apps/mobile/lib/features/business/screens/bulk_orders_screen.dart`
- Create: `apps/mobile/lib/features/business/screens/bulk_order_detail_screen.dart`
- Create: `apps/mobile/lib/features/business/models/business_profile.dart`
- Create: `apps/mobile/lib/features/business/models/bulk_order.dart`

Business registration, dashboard, bulk order creation (search produce, specify quantity), order detail with farmer quotes.

Farmer-side: View pending bulk items, quote/reject.

Add routes `/business/*` and `/farmer/bulk-orders`.

**Commit:** `feat: add B2B bulk order system`

---

## Phase 6: i18n + Polish + Deep Links

### Task 6.1: i18n Setup

**Files:**
- Create: `apps/mobile/lib/l10n/app_en.arb`
- Create: `apps/mobile/lib/l10n/app_ne.arb`
- Modify: `apps/mobile/pubspec.yaml` (add flutter_localizations, generate: true)
- Create: `apps/mobile/l10n.yaml`

Set up ARB-based localization. Mirror keys from web app's `messages/en.json` and `messages/ne.json`. Add `Localizations` delegates to `MaterialApp.router`.

Language switching reads/writes `users.lang` field.

**Commit:** `feat: add i18n with English and Nepali translations`

---

### Task 6.2: Deep Link Setup

**Files:**
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/ios/Runner/Info.plist`

Add intent filters for:
- `jirisewa://esewa/success`
- `jirisewa://esewa/failure`
- `jirisewa://khalti/callback`
- `jirisewa://connectips/success`
- `jirisewa://connectips/failure`

Handle deep links in GoRouter with `redirect` or additional routes.

**Commit:** `feat: add deep link handling for payment callbacks`

---

### Task 6.3: Order Tracking Screen (Consumer-side)

**Files:**
- Create: `apps/mobile/lib/features/orders/screens/order_tracking_screen.dart`
- Create: `apps/mobile/lib/features/orders/providers/tracking_provider.dart`

Live map showing rider position via Supabase realtime on `rider_location_log`. Shows route line, rider marker, delivery destination, ETA.

Add route `/orders/:id/tracking`.

**Commit:** `feat: add consumer-side OrderTrackingScreen with live rider position`

---

### Task 6.4: Add All New Routes to GoRouter

**Files:**
- Modify: `apps/mobile/lib/core/routing/app_router.dart`

Add all routes defined in Tasks above that haven't been added yet. Ensure all screens are imported and routes are properly nested.

**Commit:** `feat: register all feature routes in GoRouter`

---

### Task 6.5: Update Tests

**Files:**
- Modify: `apps/mobile/test/widget_test.dart`
- Modify: `apps/mobile/test/helpers/test_app.dart`
- Modify: `apps/mobile/test/helpers/mock_supabase.dart`

Update test helpers to wrap widgets in `ProviderScope` with overridden providers instead of old `SessionProvider`. Update existing tests to work with Riverpod. Add basic smoke tests for new screens.

**Commit:** `test: update test suite for Riverpod architecture`

---

### Task 6.6: Final Polish + Cleanup

**Files:**
- Remove any remaining references to old `SessionService`
- Ensure all screens follow `ui.md` design system (zero shadows, correct colors, Outfit font)
- Add Outfit font to `pubspec.yaml` assets and `theme.dart`

Run full test suite:
```bash
cd apps/mobile && flutter analyze --no-fatal-infos && flutter test
```

**Commit:** `chore: final cleanup and design system compliance`

---

## Summary

| Phase | Tasks | Key Features |
|-------|-------|-------------|
| 0 | 0.1–0.11 | Riverpod setup, core providers, migrate all 8 existing screens |
| 1 | 1.1–1.6 | Cart, checkout, payments (eSewa/Khalti/connectIPS), produce detail |
| 2 | 2.1–2.3 | Trip creation, trip detail, route planning |
| 3 | 3.1–3.8 | Chat (realtime), notifications, badges |
| 4 | 4.1–4.4 | Ratings, farmer listings, analytics, verification |
| 5 | 5.1–5.2 | Subscriptions, B2B bulk orders |
| 6 | 6.1–6.6 | i18n, deep links, order tracking, tests, polish |

**Total: 35 tasks across 7 phases.**
