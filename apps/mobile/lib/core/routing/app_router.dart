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
import 'package:jirisewa_mobile/features/subscriptions/screens/subscription_browse_screen.dart';
import 'package:jirisewa_mobile/features/subscriptions/screens/farmer_subscriptions_screen.dart';
import 'package:jirisewa_mobile/features/business/screens/business_register_screen.dart';
import 'package:jirisewa_mobile/features/business/screens/business_dashboard_screen.dart';
import 'package:jirisewa_mobile/features/business/screens/bulk_orders_screen.dart';
import 'package:jirisewa_mobile/features/business/screens/bulk_order_detail_screen.dart';
import 'package:jirisewa_mobile/features/business/screens/farmer_bulk_orders_screen.dart';
import 'package:jirisewa_mobile/features/earnings/screens/earnings_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_tracking_screen.dart';
import 'package:jirisewa_mobile/features/payments/screens/payment_callback_screen.dart';
import 'package:jirisewa_mobile/features/addresses/screens/addresses_screen.dart';

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
  static const orderTracking = '/tracking/:id';
  static const farmerListingNew = '/farmer/listings/new';
  static const farmerListingEdit = '/farmer/listings/:id/edit';
  static const farmerAnalytics = '/farmer/analytics';
  static const farmerVerification = '/farmer/verification';
  static const farmerSubscriptions = '/farmer/subscriptions';
  static const farmerBulkOrders = '/farmer/bulk-orders';
  static const earnings = '/earnings';
  static const addresses = '/addresses';
  static const subscriptions = '/subscriptions';
  static const businessRegister = '/business/register';
  static const businessDashboard = '/business/dashboard';
  static const businessOrders = '/business/orders';
  static const businessOrderDetail = '/business/orders/:id';

  // Payment callback deep link routes
  static const paymentEsewaSuccess = '/payment/esewa/success';
  static const paymentEsewaFailure = '/payment/esewa/failure';
  static const paymentKhaltiCallback = '/payment/khalti/callback';
  static const paymentConnectipsSuccess = '/payment/connectips/success';
  static const paymentConnectipsFailure = '/payment/connectips/failure';
}

abstract final class ShellBranch {
  static const home = 0;
  static const marketplace = 1;
  static const trips = 2;
  static const orders = 3;
  static const profile = 4;
}

/// A [ChangeNotifier] that triggers GoRouter's redirect when auth state changes.
/// This avoids recreating the entire GoRouter (which loses navigation state).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    // Listen to auth & profile changes and notify GoRouter to re-evaluate redirects.
    ref.listen(isAuthenticatedProvider, (_, __) => notifyListeners());
    ref.listen(hasProfileProvider, (_, __) => notifyListeners());
    ref.listen(userSessionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final sessionLoading = ref.read(userSessionProvider).isLoading;
      if (sessionLoading) return null;

      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final hasProfile = ref.read(hasProfileProvider);

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
      GoRoute(
        path: AppRoutes.subscriptions,
        builder: (context, state) => const SubscriptionBrowseScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerSubscriptions,
        builder: (context, state) => const FarmerSubscriptionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessRegister,
        builder: (context, state) => const BusinessRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessDashboard,
        builder: (context, state) => const BusinessDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessOrderDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return BulkOrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.businessOrders,
        builder: (context, state) => const BulkOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerBulkOrders,
        builder: (context, state) => const FarmerBulkOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.earnings,
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const AddressesScreen(),
      ),
      // Order tracking — full-screen map, outside shell (no bottom nav).
      GoRoute(
        path: AppRoutes.orderTracking,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      // Payment callback deep link routes
      GoRoute(
        path: AppRoutes.paymentEsewaSuccess,
        builder: (context, state) => PaymentCallbackScreen(
          gateway: 'esewa',
          result: 'success',
          queryParams: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentEsewaFailure,
        builder: (context, state) => PaymentCallbackScreen(
          gateway: 'esewa',
          result: 'failure',
          queryParams: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentKhaltiCallback,
        builder: (context, state) => PaymentCallbackScreen(
          gateway: 'khalti',
          result: state.uri.queryParameters['status'] == 'Completed'
              ? 'success'
              : 'failure',
          queryParams: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentConnectipsSuccess,
        builder: (context, state) => PaymentCallbackScreen(
          gateway: 'connectips',
          result: 'success',
          queryParams: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentConnectipsFailure,
        builder: (context, state) => PaymentCallbackScreen(
          gateway: 'connectips',
          result: 'failure',
          queryParams: state.uri.queryParameters,
        ),
      ),
    ],
  );
});
