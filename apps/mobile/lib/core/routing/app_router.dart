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
import 'package:jirisewa_mobile/features/cart/screens/cart_screen.dart';
import 'package:jirisewa_mobile/features/checkout/screens/checkout_screen.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/produce_detail_screen.dart';
import 'package:jirisewa_mobile/features/chat/screens/chat_screen.dart';
import 'package:jirisewa_mobile/features/chat/screens/conversations_screen.dart';
import 'package:jirisewa_mobile/features/shell/app_shell.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/trip_creation_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/route_plan_screen.dart';
import 'package:jirisewa_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:jirisewa_mobile/features/notifications/screens/notification_preferences_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/trip_detail_screen.dart';
import 'package:jirisewa_mobile/features/farmer/screens/create_listing_screen.dart';
import 'package:jirisewa_mobile/features/farmer/screens/edit_listing_screen.dart';
import 'package:jirisewa_mobile/features/farmer/screens/analytics_screen.dart';
import 'package:jirisewa_mobile/features/farmer/screens/verification_screen.dart';

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
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatDetail,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.produceDetail,
        builder: (context, state) {
          final listingId = state.pathParameters['id']!;
          return ProduceDetailScreen(listingId: listingId);
        },
      ),
      GoRoute(
        path: AppRoutes.tripNew,
        builder: (context, state) => const TripCreationScreen(),
      ),
      GoRoute(
        path: AppRoutes.tripPlan,
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return RoutePlanScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.tripDetail,
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripDetailScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.farmerListingNew,
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerListingEdit,
        builder: (context, state) {
          final listingId = state.pathParameters['id']!;
          return EditListingScreen(listingId: listingId);
        },
      ),
      GoRoute(
        path: AppRoutes.farmerAnalytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerVerification,
        builder: (context, state) => const VerificationScreen(),
      ),
    ],
  );
});
