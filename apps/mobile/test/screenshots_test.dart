@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/auth/screens/login_screen.dart';
import 'package:jirisewa_mobile/features/auth/screens/register_screen.dart';
import 'package:jirisewa_mobile/features/home/screens/home_screen.dart';
import 'package:jirisewa_mobile/features/marketplace/screens/marketplace_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/order_detail_screen.dart';
import 'package:jirisewa_mobile/features/orders/screens/orders_screen.dart';
import 'package:jirisewa_mobile/features/profile/screens/profile_screen.dart';
import 'package:jirisewa_mobile/features/trips/screens/trips_screen.dart';

import 'helpers/mock_supabase.dart';
import 'helpers/test_app.dart';
import 'helpers/test_data.dart';

/// Phone viewport size (logical pixels) for consistent golden files.
const _phoneSize = Size(390, 844);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Load real fonts so golden files render readable text instead of
    // the Ahem test font (which shows every glyph as a square).
    await _loadFonts();

    // Initialize Supabase with mock HTTP transport so screens that access
    // Supabase.instance.client get mock data instead of network errors.
    // EmptyLocalStorage + _NoopAsyncStorage avoid SharedPreferences
    // platform channels that are unavailable in headless widget tests.
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

  // ---------------------------------------------------------------------------
  // Auth flow
  // ---------------------------------------------------------------------------

  group('Auth flow', () {
    testWidgets('01 — login phone form', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/01_login_phone.png'),
      );
    });

    testWidgets('02 — login phone entered', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '9812345678');
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/02_login_phone_entered.png'),
      );
    });

    testWidgets('03 — register step 1 personal info', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/03_register_step1.png'),
      );
    });

    testWidgets('04 — register step 2 role selection', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/04_register_step2.png'),
      );
    });

    testWidgets('05 — register step 2 roles selected', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Farmer'));
      await tester.tap(find.text('Rider'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/05_register_step2_selected.png'),
      );
    });

    testWidgets('06 — register step 3 role details', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test User');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Farmer'));
      await tester.tap(find.text('Rider'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/06_register_step3.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Home dashboard
  // ---------------------------------------------------------------------------

  group('Home dashboard', () {
    testWidgets('07 — consumer dashboard', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'consumer',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/07_home_consumer.png'),
      );
    });

    testWidgets('08 — farmer dashboard', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'farmer',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/08_home_farmer.png'),
      );
    });

    testWidgets('09 — rider dashboard', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        activeRole: 'rider',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/09_home_rider.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Marketplace
  // ---------------------------------------------------------------------------

  group('Marketplace', () {
    testWidgets('10 — marketplace placeholder', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(
        child: const MarketplaceScreen(),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/10_marketplace.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  group('Orders', () {
    testWidgets('11 — consumer orders list', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const OrdersScreen(),
        activeRole: 'consumer',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/11_orders_consumer.png'),
      );
    });

    testWidgets('12 — rider orders list', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const OrdersScreen(),
        activeRole: 'rider',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/12_orders_rider.png'),
      );
    });

    testWidgets('13 — order detail', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildBareTestApp(
        child: OrderDetailScreen(
          orderId: mockOrders.first['id'] as String,
        ),
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/13_order_detail.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  group('Trips', () {
    testWidgets('14 — rider trips list', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const TripsScreen(),
        activeRole: 'rider',
      ));
      await _pumpUntilLoaded(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/14_trips_rider.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  group('Profile', () {
    testWidgets('15 — profile view', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const ProfileScreen(),
        activeRole: 'consumer',
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/15_profile_view.png'),
      );
    });

    testWidgets('16 — profile edit mode', (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(buildTestApp(
        child: const ProfileScreen(),
        activeRole: 'consumer',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/16_profile_edit.png'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation — shell with bottom tabs
  // ---------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('17 — consumer bottom tabs', (tester) async {
      await _setPhoneViewport(tester);
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

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/17_nav_consumer_tabs.png'),
      );
    });

    testWidgets('18 — rider bottom tabs', (tester) async {
      await _setPhoneViewport(tester);
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

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('screenshots/18_nav_rider_tabs.png'),
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

/// Lets async data loading (mock HTTP) complete, then rebuilds the UI.
///
/// Widget tests use [FakeAsync] which doesn't process real I/O callbacks.
/// [WidgetTester.runAsync] switches to a real async zone so the [MockClient]
/// responses can resolve. We then pump a fixed number of frames rather than
/// using [pumpAndSettle] which hangs on infinite animations or repeated
/// [didChangeDependencies] → [setState] cycles.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  // Let real async I/O (mock HTTP responses) complete.
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 500));
  });
  // Pump frames to rebuild with loaded data. Avoid pumpAndSettle which
  // hangs on CircularProgressIndicator and other infinite animations.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Sets a phone-sized viewport for consistent golden files.
Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Loads Roboto and MaterialIcons fonts from the Flutter SDK cache so golden
/// files render readable text instead of Ahem squares.
Future<void> _loadFonts() async {
  final fontDir = '${_findFlutterRoot()}/bin/cache/artifacts/material_fonts';

  // Load Roboto variants for normal, bold, medium, and light text.
  final robotoLoader = FontLoader('Roboto');
  for (final variant in ['Regular', 'Bold', 'Medium', 'Light', 'Thin']) {
    final file = File('$fontDir/Roboto-$variant.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      robotoLoader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    }
  }
  await robotoLoader.load();

  // Load italic variants.
  final robotoItalicLoader = FontLoader('Roboto');
  for (final variant in [
    'Italic',
    'BoldItalic',
    'MediumItalic',
    'LightItalic',
    'ThinItalic',
  ]) {
    final file = File('$fontDir/Roboto-$variant.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      robotoItalicLoader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
      );
    }
  }
  await robotoItalicLoader.load();

  // Load MaterialIcons for icon rendering.
  final iconFile = File('$fontDir/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = iconFile.readAsBytesSync();
    iconLoader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
    await iconLoader.load();
  }
}

/// Locates the Flutter SDK root directory.
String _findFlutterRoot() {
  // FLUTTER_ROOT is set by the flutter tool when running tests.
  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) return envRoot;

  // Fallback: resolve the flutter binary.
  final result = Process.runSync('which', ['flutter']);
  if (result.exitCode == 0) {
    final bin = (result.stdout as String).trim();
    try {
      final resolved = File(bin).resolveSymbolicLinksSync();
      return File(resolved).parent.parent.path;
    } catch (_) {
      // If symlink resolution fails, try parent of bin directory.
      return File(bin).parent.parent.path;
    }
  }

  throw StateError(
    'Cannot find Flutter SDK root. Set FLUTTER_ROOT environment variable.',
  );
}

/// No-op [GotrueAsyncStorage] for test-mode PKCE storage.
///
/// Avoids SharedPreferences platform channel calls that are unavailable
/// in headless widget tests.
class _NoopAsyncStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> removeItem({required String key}) async {}

  @override
  Future<void> setItem({required String key, required String value}) async {}
}
