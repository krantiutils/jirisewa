import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/addresses/models/saved_address.dart';
import 'package:jirisewa_mobile/features/addresses/repositories/address_repository.dart';

/// Provider for the AddressRepository, wired to the Supabase client.
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(supabaseProvider));
});

/// Fetches saved addresses for the current user (default address first).
final addressesProvider =
    FutureProvider.autoDispose<List<SavedAddress>>((ref) async {
  final repo = ref.watch(addressRepositoryProvider);
  final profile = ref.watch(userProfileProvider);

  if (profile == null) return const [];

  return repo.listAddresses(profile.id);
});
