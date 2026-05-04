// Render hub screens with mock data and dump full-page PNGs to disk.
// Used to generate demo screenshots for the Jiri municipality deck without
// needing a device connected to a Supabase backend that has hub schema.
//
// Run:
//   cd apps/mobile && flutter test test/features/hubs/hub_screens_render_test.dart
// Output: docs/demo/screenshots/android/hub-*.png (1080x2400)

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/hubs/providers/hub_providers.dart';
import 'package:jirisewa_mobile/features/hubs/repositories/hub_repository.dart';
import 'package:jirisewa_mobile/features/hubs/screens/farmer_dropoff_screen.dart';
import 'package:jirisewa_mobile/features/hubs/screens/hub_inventory_screen.dart';

import '../../helpers/test_app.dart';

const _outDir = '../../docs/demo/screenshots/android';

class _MockRepo implements HubRepository {
  final List<HubInfo> hubs;
  final List<Map<String, dynamic>> listings;
  final List<DropoffInfo> myDropoffs;
  final HubInfo? operatedHub;
  final List<DropoffInfo> inventory;
  _MockRepo({
    this.hubs = const [],
    this.listings = const [],
    this.myDropoffs = const [],
    this.operatedHub,
    this.inventory = const [],
  });
  @override
  Future<List<HubInfo>> listOriginHubs() async => hubs;
  @override
  Future<List<Map<String, dynamic>>> listMyActiveListings(String _) async => listings;
  @override
  Future<Map<String, dynamic>> recordDropoff({
    required String hubId,
    required String listingId,
    required double quantityKg,
  }) async =>
      {'dropoff_id': 'd-1', 'lot_code': 'X12345', 'expires_at': '2026-05-01T10:00:00Z'};
  @override
  Future<List<DropoffInfo>> listMyDropoffs(String _) async => myDropoffs;
  @override
  Future<HubInfo?> getMyOperatedHub(String _) async => operatedHub;
  @override
  Future<List<DropoffInfo>> listHubInventory(String _) async => inventory;
  @override
  Future<void> markReceived(String _) async {}
  @override
  Future<void> markSpoiled(String dropoffId, {String? notes}) async {}
  @override
  Future<void> dispatchToTrip(String _, String __) async {}
}

DropoffInfo _drop({
  required String id,
  required String lot,
  required String status,
  String listing = 'Tomatoes',
  String farmer = 'Bibek Tamang',
  double qty = 5,
}) =>
    DropoffInfo(
      id: id,
      hubId: 'hub-1',
      hubName: 'Jiri Bazaar Hub',
      listingId: 'lst-1',
      listingName: listing,
      farmerId: 'f-$id',
      farmerName: farmer,
      quantityKg: qty,
      lotCode: lot,
      status: status,
      droppedAt: DateTime(2026, 4, 29, 10, 30),
      receivedAt: status == 'in_inventory' ? DateTime(2026, 4, 29, 11) : null,
      dispatchedAt: null,
      expiresAt: DateTime(2026, 5, 1, 10, 30),
    );

Future<void> _capture(WidgetTester tester, String slug) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));

  // Find the root RenderRepaintBoundary the binding sets up for tests.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = binding.renderViewElement!.findRenderObject() as RenderObject;
  RenderRepaintBoundary? rrb;
  void visit(RenderObject node) {
    if (rrb != null) return;
    if (node is RenderRepaintBoundary) {
      rrb = node;
      return;
    }
    node.visitChildren(visit);
  }
  visit(boundary);
  if (rrb == null) {
    // ignore: avoid_print
    print('no RenderRepaintBoundary found, skipping $slug');
    return;
  }
  final ui.Image image = await rrb!.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;
  final bytes = byteData.buffer.asUint8List();
  final outFile = File('$_outDir/$slug.png');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Phone-shaped viewport (logical px ≈ 360x800; pixelRatio handled by host).
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
    binding.window.devicePixelRatioTestValue = 3.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });
  });

  testWidgets('farmer dropoff screen — empty', (tester) async {
    final repo = _MockRepo(
      hubs: [
        const HubInfo(
          id: 'hub-1',
          nameEn: 'Jiri Bazaar Hub',
          nameNe: 'जिरी बजार हब',
          address: 'Jiri Bazaar, Main Square, Dolakha',
          hubType: 'origin',
        ),
      ],
      listings: [
        {'id': 'lst-1', 'name_en': 'Tomatoes', 'pickup_mode': 'farm_pickup'},
        {'id': 'lst-2', 'name_en': 'Potato', 'pickup_mode': 'both'},
      ],
      myDropoffs: const [],
    );
    await tester.pumpWidget(buildTestApp(
      child: const FarmerDropoffScreen(),
      activeRole: 'farmer',
      extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
    ));
    await _capture(tester, 'm-10-farmer-dropoff-empty');
  });

  testWidgets('farmer dropoff screen — with recent dropoffs', (tester) async {
    final repo = _MockRepo(
      hubs: [
        const HubInfo(
          id: 'hub-1',
          nameEn: 'Jiri Bazaar Hub',
          nameNe: 'जिरी बजार हब',
          address: 'Jiri Bazaar, Main Square, Dolakha',
          hubType: 'origin',
        ),
      ],
      listings: [
        {'id': 'lst-1', 'name_en': 'Tomatoes', 'pickup_mode': 'both'},
      ],
      myDropoffs: [
        _drop(id: '1', lot: 'NYGJ38', status: 'in_inventory', listing: 'Potato'),
        _drop(id: '2', lot: 'CHL9B8', status: 'dropped_off', listing: 'Tomatoes'),
        _drop(id: '3', lot: 'MKA5LT', status: 'dispatched', listing: 'Curd', qty: 3),
      ],
    );
    await tester.pumpWidget(buildTestApp(
      child: const FarmerDropoffScreen(),
      activeRole: 'farmer',
      extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
    ));
    await _capture(tester, 'm-11-farmer-dropoff-list');
  });

  testWidgets('hub operator inventory — full', (tester) async {
    final repo = _MockRepo(
      operatedHub: const HubInfo(
        id: 'hub-1',
        nameEn: 'Jiri Bazaar Hub',
        nameNe: 'जिरी बजार हब',
        address: 'Jiri Bazaar, Main Square, Dolakha',
        hubType: 'origin',
      ),
      inventory: [
        _drop(id: '1', lot: 'NYGJ38', status: 'dropped_off', listing: 'Potato', farmer: 'Bibek Tamang'),
        _drop(id: '2', lot: 'CHL9B8', status: 'dropped_off', listing: 'Tomatoes', farmer: 'Sita Sharma'),
        _drop(id: '3', lot: 'MKA5LT', status: 'in_inventory', listing: 'Curd', farmer: 'Hari Khadka', qty: 3),
        _drop(id: '4', lot: '7NJ9CM', status: 'dispatched', listing: 'Spinach', farmer: 'Kalpana Rai'),
      ],
    );
    await tester.pumpWidget(buildTestApp(
      child: const HubInventoryScreen(),
      activeRole: 'hub_operator',
      extraOverrides: [hubRepositoryProvider.overrideWithValue(repo)],
    ));
    await _capture(tester, 'm-20-hub-inventory');
  });
}
