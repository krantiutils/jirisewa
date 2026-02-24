import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/marketplace/providers/marketplace_provider.dart';

/// Fetches a single produce listing by ID with joined farmer, category,
/// and municipality data. Auto-disposes when the detail screen is popped.
final produceDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, listingId) async {
    final repo = ref.watch(produceRepositoryProvider);
    return repo.getListingDetail(listingId);
  },
);

/// Fetches the farmer's bio from the user_profiles table.
/// Returns null if no profile or no bio is set.
final farmerBioProvider =
    FutureProvider.autoDispose.family<String?, String>(
  (ref, farmerId) async {
    final client = ref.watch(supabaseProvider);
    final result = await client
        .from('user_profiles')
        .select('bio')
        .eq('id', farmerId)
        .maybeSingle();
    return result?['bio'] as String?;
  },
);
