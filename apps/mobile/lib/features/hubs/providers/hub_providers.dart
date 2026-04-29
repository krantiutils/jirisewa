import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/hubs/repositories/hub_repository.dart';

final hubRepositoryProvider = Provider<HubRepository>((ref) {
  return HubRepository(ref.watch(supabaseProvider));
}, dependencies: [supabaseProvider]);

final originHubsProvider =
    FutureProvider.autoDispose<List<HubInfo>>((ref) async {
  final repo = ref.watch(hubRepositoryProvider);
  return repo.listOriginHubs();
}, dependencies: [hubRepositoryProvider]);

final myActiveListingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return [];
  final repo = ref.watch(hubRepositoryProvider);
  return repo.listMyActiveListings(profile.id);
}, dependencies: [hubRepositoryProvider, userProfileProvider]);

final myDropoffsProvider =
    FutureProvider.autoDispose<List<DropoffInfo>>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return [];
  final repo = ref.watch(hubRepositoryProvider);
  return repo.listMyDropoffs(profile.id);
}, dependencies: [hubRepositoryProvider, userProfileProvider]);

final myOperatedHubProvider =
    FutureProvider.autoDispose<HubInfo?>((ref) async {
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return null;
  final repo = ref.watch(hubRepositoryProvider);
  return repo.getMyOperatedHub(profile.id);
}, dependencies: [hubRepositoryProvider, userProfileProvider]);

final hubInventoryProvider = FutureProvider.autoDispose
    .family<List<DropoffInfo>, String>((ref, hubId) async {
  final repo = ref.watch(hubRepositoryProvider);
  return repo.listHubInventory(hubId);
}, dependencies: [hubRepositoryProvider]);
