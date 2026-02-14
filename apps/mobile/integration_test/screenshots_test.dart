import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';
import 'package:jirisewa_mobile/features/auth/screens/register_screen.dart';
import 'package:jirisewa_mobile/features/home/screens/home_screen.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/marketplace_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/orders_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_detail_screen.dart';
import 'package:jirisewa_mobile/features/profile/screens/profile_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';

import 'helpers/mock_supabase.dart';
import 'helpers/screenshot_helper.dart';
import 'helpers/test_app.dart';
import 'helpers/test_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Supabase with a mock HTTP client so screens that access
    // Supabase.instance.client get mock data instead of network errors.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
      httpClient: createMockSupabaseClient(),
    );
  });

  // ---------------------------------------------------------------------------
  // Auth flow
  // ---------------------------------------------------------------------------

  group('Auth flow', () {
    testWidgets('login screen — phone form', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Login to JiriSewa'), findsOneWidget);
      expect(find.text('+977'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '01_login_phone');
    });

    testWidgets('login screen — phone entered', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      // Enter a valid phone number.
      await tester.enterText(find.byType(TextField).first, '9812345678');
      await tester.pump();

      await takeAndSaveScreenshot(binding, '02_login_phone_entered');
    });

    testWidgets('register screen — step 1 personal info', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '03_register_step1');
    });

    testWidgets('register screen — step 2 role selection', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      // Fill step 1 and advance.
      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('I am a...'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '04_register_step2');
    });

    testWidgets('register screen — step 2 roles selected', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      // Fill step 1 and advance.
      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Select farmer and rider roles.
      await tester.tap(find.text('Farmer'));
      await tester.tap(find.text('Rider'));
      await tester.pumpAndSettle();

      await takeAndSaveScreenshot(binding, '05_register_step2_selected');
    });

    testWidgets('register screen — step 3 role details', (tester) async {
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      // Fill step 1 and advance.
      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Select farmer + rider, advance.
      await tester.tap(find.text('Farmer'));
      await tester.tap(find.text('Rider'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Farm Name'), findsOneWidget);
      expect(find.text('Vehicle Type'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '06_register_step3');
    });
  });

  // ---------------------------------------------------------------------------
  // Home dashboard
  // ---------------------------------------------------------------------------

  group('Home dashboard', () {
    testWidgets('consumer dashboard', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'consumer',
      ));
      // Pump a few frames to allow async data load from mock client.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Consumer Dashboard'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '07_home_consumer');
    });

    testWidgets('farmer dashboard', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'farmer',
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Farmer Dashboard'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '08_home_farmer');
    });

    testWidgets('rider dashboard', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'rider',
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rider Dashboard'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '09_home_rider');
    });
  });

  // ---------------------------------------------------------------------------
  // Marketplace
  // ---------------------------------------------------------------------------

  group('Marketplace', () {
    testWidgets('marketplace placeholder', (tester) async {
      await tester.pumpWidget(buildBareTestApp(
        child: const MarketplaceScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Marketplace'), findsOneWidget);
      expect(find.textContaining('Coming soon'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '10_marketplace');
    });
  });

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  group('Orders', () {
    testWidgets('consumer orders list', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const OrdersScreen(),
        activeRole: 'consumer',
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('My Orders'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '11_orders_consumer');
    });

    testWidgets('rider orders list', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const OrdersScreen(),
        activeRole: 'rider',
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('My Orders'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '12_orders_rider');
    });

    testWidgets('order detail', (tester) async {
      await tester.pumpWidget(buildBareTestApp(
        child: OrderDetailScreen(
          orderId: mockOrders.first['id'] as String,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Order #'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '13_order_detail');
    });
  });

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  group('Trips', () {
    testWidgets('rider trips list', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const TripsScreen(),
        activeRole: 'rider',
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '14_trips_rider');
    });
  });

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  group('Profile', () {
    testWidgets('profile view', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const ProfileScreen(),
        activeRole: 'consumer',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sita Sharma'), findsOneWidget);
      expect(find.text('9812345678'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '15_profile_view');
    });

    testWidgets('profile edit mode', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const ProfileScreen(),
        activeRole: 'consumer',
      ));
      await tester.pumpAndSettle();

      // Tap edit button.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '16_profile_edit');
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation — shell with bottom tabs
  // ---------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('consumer bottom tabs', (tester) async {
      // Render the profile screen inside a Scaffold with fake bottom nav
      // to demonstrate the tab layout without needing full GoRouter.
      await tester.pumpWidget(buildTestApp(
        child: Scaffold(
          body: const Center(child: Text('Home')),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.storefront_outlined),
                activeIcon: Icon(Icons.storefront),
                label: 'Marketplace',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outlined),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
        activeRole: 'consumer',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Marketplace'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '17_nav_consumer_tabs');
    });

    testWidgets('rider bottom tabs', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: Scaffold(
          body: const Center(child: Text('Home')),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.route_outlined),
                activeIcon: Icon(Icons.route),
                label: 'Trips',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outlined),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
        activeRole: 'rider',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Trips'), findsOneWidget);

      await takeAndSaveScreenshot(binding, '18_nav_rider_tabs');
    });
  });
}
