import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/features/ratings/repositories/rating_repository.dart';

/// Provides the [RatingRepository] wired to the Supabase client.
final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  return RatingRepository(ref.watch(supabaseProvider));
});

/// Fetches the rating status for an order -- who the current user can rate
/// and who they have already rated.
final orderRatingStatusProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, orderId) async {
    final repo = ref.watch(ratingRepositoryProvider);
    final profile = ref.watch(userProfileProvider);
    if (profile == null) {
      return {'canRate': <Map<String, dynamic>>[], 'alreadyRated': <Map<String, dynamic>>[]};
    }
    return repo.getOrderRatingStatus(orderId, profile.id);
  },
);

/// Fetches paginated ratings received by a given user.
final userRatingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, userId) async {
    final repo = ref.watch(ratingRepositoryProvider);
    return repo.getUserRatings(userId);
  },
);
