import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';
import 'package:jirisewa_mobile/features/auth/screens/register_screen.dart';
import 'package:jirisewa_mobile/features/home/screens/home_screen.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/marketplace_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/orders_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_detail_screen.dart';
import 'package:jirisewa_mobile/features/profile/screens/profile_screen.dart';
import 'package:jirisewa_mobile/features/shell/app_shell.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const marketplace = '/marketplace';
  static const trips = '/trips';
  static const orders = '/orders';
  static const orderDetail = '/orders/:id';
  static const profile = '/profile';
}

/// Branch indices for the StatefulShellRoute.
/// These are the indices into the `branches` list below.
abstract final class ShellBranch {
  static const home = 0;
  static const marketplace = 1;
  static const trips = 2;
  static const orders = 3;
  static const profile = 4;
}

GoRouter buildRouter(SessionService session) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: session,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = session.isAuthenticated;
      final hasProfile = session.hasProfile;
      final isLoading = session.loading;

      // While loading, don't redirect — let the current route stay.
      if (isLoading) return null;

      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnRegister = state.matchedLocation == AppRoutes.register;
      final isAuthRoute = isOnLogin || isOnRegister;

      // Not authenticated → force to login (unless already there).
      if (!isLoggedIn) {
        return isOnLogin ? null : AppRoutes.login;
      }

      // Authenticated but no profile → force to register.
      if (!hasProfile) {
        return isOnRegister ? null : AppRoutes.register;
      }

      // Authenticated with profile but on auth route → go home.
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
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Branch 1: Marketplace (consumer/farmer)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          // Branch 2: Trips (rider)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.trips,
                builder: (context, state) => const TripsScreen(),
              ),
            ],
          ),
          // Branch 3: Orders
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
          // Branch 4: Profile
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
}
