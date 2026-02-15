import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';
import 'package:jirisewa_mobile/features/auth/screens/register_screen.dart';
import 'package:jirisewa_mobile/features/home/screens/home_screen.dart';
import 'package:jirisewa_mobile/features/map/widgets/listings_map.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/marketplace_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_detail_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/orders_screen.dart';
import 'package:jirisewa_mobile/features/profile/screens/profile_screen.dart';
import 'package:jirisewa_mobile/features/tracking/screens/trip_tracking_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';

import 'helpers/mock_supabase.dart';
import 'helpers/test_app.dart';
import 'helpers/test_data.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
      httpClient: createMockHttpClient(),
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _NoopAsyncStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      debug: false,
    );
  });

  group('Auth flow', () {
    testWidgets('login form renders and accepts phone input', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Login to JiriSewa'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '9812345678');
      await tester.pump();

      expect(find.text('9812345678'), findsOneWidget);
    });

    testWidgets('register advances to role details', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Farmer'));
      await tester.tap(find.text('Rider'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Farm Name'), findsOneWidget);
      expect(find.text('Vehicle Type'), findsOneWidget);
    });
  });

  group('Dashboard data validation', () {
    testWidgets('farmer dashboard shows pending pickups from mock data', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(child: const HomeScreen(), activeRole: 'farmer'),
      );
      await _pumpUntilLoaded(tester);

      expect(find.textContaining('Farmer Dashboard'), findsOneWidget);
      expect(find.text('No pending pickups'), findsNothing);
      expect(find.textContaining('Awaiting pickup'), findsWidgets);
    });

    testWidgets('mock Supabase filters eq and in results', (tester) async {
      final client = createMockSupabaseClient();

      final riderTrips = await client
          .from('rider_trips')
          .select('id, status')
          .eq('rider_id', testUserId)
          .inFilter('status', ['scheduled', 'in_transit']);

      final orderItems = await client
          .from('order_items')
          .select('id, pickup_confirmed')
          .eq('pickup_confirmed', false);

      expect((riderTrips as List).length, 2);
      expect((orderItems as List).length, 1);
    });
  });

  group('Map integration', () {
    testWidgets('marketplace renders listings map widget', (tester) async {
      await tester.pumpWidget(
        buildBareTestApp(child: const MarketplaceScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Marketplace Flow'), findsOneWidget);
      expect(find.byType(ListingsMapWidget), findsOneWidget);
      expect(find.text('Tomatoes'), findsOneWidget);
    });

    testWidgets('trips screen renders route maps in trip cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(child: const TripsScreen(), activeRole: 'rider'),
      );
      await _pumpUntilLoaded(tester);

      expect(find.text('Rider Connection Flow'), findsOneWidget);
      expect(find.byType(RouteMapWidget), findsWidgets);
    });

    testWidgets('trip tracking screen renders route map and controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildBareTestApp(
          child: TripTrackingScreen(
            tripId: 'trip-1',
            origin: const LatLng(27.6306, 86.2305),
            destination: const LatLng(27.7172, 85.3240),
            originName: 'Jiri',
            destinationName: 'Kathmandu',
            routeCoordinates: const [
              LatLng(27.6306, 86.2305),
              LatLng(27.7172, 85.3240),
            ],
            initialStatus: 'scheduled',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RouteMapWidget), findsOneWidget);
      expect(find.text('Start Trip'), findsOneWidget);
    });
  });

  group('Core screens smoke test', () {
    testWidgets('orders screen loads for consumer role', (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: const OrdersScreen(), activeRole: 'consumer'),
      );
      await _pumpUntilLoaded(tester);

      expect(find.text('My Orders'), findsOneWidget);
    });

    testWidgets('order detail renders for mock order', (tester) async {
      await tester.pumpWidget(
        buildBareTestApp(
          child: OrderDetailScreen(orderId: mockOrders.first['id'] as String),
        ),
      );
      await _pumpUntilLoaded(tester);

      expect(find.textContaining('Order #'), findsOneWidget);
    });

    testWidgets('profile screen loads in view and edit mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: const ProfileScreen(), activeRole: 'consumer'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });
  });
}

class _NoopAsyncStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {}

  @override
  Future<void> removeItem({required String key}) async {}
}

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 500));
  });
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
