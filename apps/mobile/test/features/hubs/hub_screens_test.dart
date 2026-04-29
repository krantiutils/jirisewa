import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/hubs/providers/hub_providers.dart';
import 'package:jirisewa_mobile/features/hubs/repositories/hub_repository.dart';
import 'package:jirisewa_mobile/features/hubs/screens/farmer_dropoff_screen.dart';
import 'package:jirisewa_mobile/features/hubs/screens/hub_inventory_screen.dart';

import '../../helpers/test_app.dart';

class _FakeHubRepository implements HubRepository {
  final List<HubInfo> hubs;
  final List<Map<String, dynamic>> listings;
  final List<DropoffInfo> myDropoffs;
  final HubInfo? operatedHub;
  final List<DropoffInfo> inventory;
  final Map<String, dynamic>? recordResult;
  final Object? recordError;

  int recordCalls = 0;
  int receiveCalls = 0;
  int spoilCalls = 0;
  String? lastReceivedId;
  String? lastSpoiledId;

  _FakeHubRepository({
    this.hubs = const [],
    this.listings = const [],
    this.myDropoffs = const [],
    this.operatedHub,
    this.inventory = const [],
    this.recordResult,
    this.recordError,
  });

  @override
  Future<List<HubInfo>> listOriginHubs() async => hubs;

  @override
  Future<List<Map<String, dynamic>>> listMyActiveListings(String farmerId) async => listings;

  @override
  Future<Map<String, dynamic>> recordDropoff({
    required String hubId,
    required String listingId,
    required double quantityKg,
  }) async {
    recordCalls++;
    if (recordError != null) throw recordError!;
    return recordResult ??
        {
          'dropoff_id': 'do-1',
          'lot_code': 'ABCD12',
          'expires_at': DateTime.now().add(const Duration(hours: 48)).toIso8601String(),
        };
  }

  @override
  Future<List<DropoffInfo>> listMyDropoffs(String farmerId) async => myDropoffs;

  @override
  Future<HubInfo?> getMyOperatedHub(String operatorId) async => operatedHub;

  @override
  Future<List<DropoffInfo>> listHubInventory(String hubId) async => inventory;

  @override
  Future<void> markReceived(String dropoffId) async {
    receiveCalls++;
    lastReceivedId = dropoffId;
  }

  @override
  Future<void> markSpoiled(String dropoffId, {String? notes}) async {
    spoilCalls++;
    lastSpoiledId = dropoffId;
  }

  @override
  Future<void> dispatchToTrip(String dropoffId, String riderTripId) async {}
}

DropoffInfo _dropoff({
  required String id,
  required String lot,
  required String status,
  String listing = 'Tomatoes',
  String farmer = 'Bibek',
  double qty = 5,
}) {
  return DropoffInfo(
    id: id,
    hubId: 'hub-1',
    hubName: 'Jiri Bazaar',
    listingId: 'lst-1',
    listingName: listing,
    farmerId: 'f-1',
    farmerName: farmer,
    quantityKg: qty,
    lotCode: lot,
    status: status,
    droppedAt: DateTime(2026, 4, 29, 10),
    receivedAt: status == 'in_inventory' ? DateTime(2026, 4, 29, 11) : null,
    dispatchedAt: null,
    expiresAt: DateTime(2026, 5, 1, 10),
  );
}

void main() {
  group('FarmerDropoffScreen', () {
    testWidgets('shows notice when no hubs available', (tester) async {
      final repo = _FakeHubRepository(hubs: [], listings: []);
      await tester.pumpWidget(
        buildTestApp(
          child: const FarmerDropoffScreen(),
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No active origin hubs'), findsOneWidget);
    });

    testWidgets('shows notice when no listings', (tester) async {
      final repo = _FakeHubRepository(
        hubs: [
          const HubInfo(
            id: 'hub-1',
            nameEn: 'Jiri Bazaar',
            nameNe: 'जिरी बजार',
            address: 'Bazaar',
            hubType: 'origin',
          ),
        ],
        listings: [],
      );
      await tester.pumpWidget(
        buildTestApp(
          child: const FarmerDropoffScreen(),
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Create an active listing first'), findsOneWidget);
    });

    testWidgets('renders form and submits dropoff', (tester) async {
      final repo = _FakeHubRepository(
        hubs: [
          const HubInfo(
            id: 'hub-1',
            nameEn: 'Jiri Bazaar',
            nameNe: 'जिरी बजार',
            address: 'Bazaar',
            hubType: 'origin',
          ),
        ],
        listings: [
          {'id': 'lst-1', 'name_en': 'Tomatoes', 'pickup_mode': 'farm_pickup'},
        ],
      );
      await tester.pumpWidget(
        buildTestApp(
          child: const FarmerDropoffScreen(),
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dropoff-submit')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('dropoff-submit')));
      await tester.tap(find.byKey(const Key('dropoff-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.recordCalls, 1);
      expect(find.byKey(const Key('dropoff-success')), findsOneWidget);
      expect(find.textContaining('ABCD12'), findsOneWidget);
    });

    testWidgets('surfaces server error to user', (tester) async {
      final repo = _FakeHubRepository(
        hubs: [
          const HubInfo(
            id: 'hub-1',
            nameEn: 'Jiri Bazaar',
            nameNe: 'जिरी बजार',
            address: 'Bazaar',
            hubType: 'origin',
          ),
        ],
        listings: [
          {'id': 'lst-1', 'name_en': 'Tomatoes', 'pickup_mode': 'farm_pickup'},
        ],
        recordError: Exception('Hub closed'),
      );
      await tester.pumpWidget(
        buildTestApp(
          child: const FarmerDropoffScreen(),
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dropoff-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hub closed'), findsOneWidget);
    });
  });

  group('HubInventoryScreen', () {
    testWidgets('shows operator-not-assigned notice', (tester) async {
      final repo = _FakeHubRepository(operatedHub: null);
      await tester.pumpWidget(
        buildTestApp(
          child: const HubInventoryScreen(),
          activeRole: 'hub_operator',
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not assigned as the operator'), findsOneWidget);
    });

    testWidgets('lists inventory rows and filters by status', (tester) async {
      final repo = _FakeHubRepository(
        operatedHub: const HubInfo(
          id: 'hub-1',
          nameEn: 'Jiri Bazaar',
          nameNe: 'जिरी बजार',
          address: 'Bazaar',
          hubType: 'origin',
        ),
        inventory: [
          _dropoff(id: 'd1', lot: 'AAA111', status: 'dropped_off'),
          _dropoff(id: 'd2', lot: 'BBB222', status: 'in_inventory'),
        ],
      );
      await tester.pumpWidget(
        buildTestApp(
          child: const HubInventoryScreen(),
          activeRole: 'hub_operator',
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jiri Bazaar'), findsWidgets);
      expect(find.byKey(const Key('inventory-row-d1')), findsOneWidget);
      expect(find.byKey(const Key('inventory-row-d2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-in_inventory')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inventory-row-d1')), findsNothing);
      expect(find.byKey(const Key('inventory-row-d2')), findsOneWidget);
    });

    testWidgets('mark received calls repository', (tester) async {
      final repo = _FakeHubRepository(
        operatedHub: const HubInfo(
          id: 'hub-1',
          nameEn: 'Jiri Bazaar',
          nameNe: 'जिरी बजार',
          address: 'Bazaar',
          hubType: 'origin',
        ),
        inventory: [
          _dropoff(id: 'd1', lot: 'AAA111', status: 'dropped_off'),
        ],
      );
      await tester.pumpWidget(
        buildTestApp(
          child: const HubInventoryScreen(),
          activeRole: 'hub_operator',
          extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('receive-d1')));
      await tester.pumpAndSettle();
      expect(repo.receiveCalls, 1);
      expect(repo.lastReceivedId, 'd1');
    });
  });
}
