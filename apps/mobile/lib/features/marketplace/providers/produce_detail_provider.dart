import 'package:flutter_riverpod/flutter_riverpod.dart';

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
