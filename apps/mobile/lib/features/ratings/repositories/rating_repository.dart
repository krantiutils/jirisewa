import 'package:supabase_flutter/supabase_flutter.dart';

class RatingRepository {
  final SupabaseClient _client;
  RatingRepository(this._client);

  /// Submit a rating. Returns the created rating row.
  Future<Map<String, dynamic>> submitRating({
    required String orderId,
    required String raterId,
    required String ratedId,
    required String roleRated,
    required int score,
    String? comment,
  }) async {
    final row = await _client
        .from('ratings')
        .insert({
          'order_id': orderId,
          'rater_id': raterId,
          'rated_id': ratedId,
          'role_rated': roleRated,
          'score': score,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  /// Get rating status for an order -- who can be rated and who has been rated.
  ///
  /// Returns `{canRate: [...], alreadyRated: [...]}` where each entry contains
  /// `{id, name, roleRated}` and alreadyRated entries also include `score`.
  Future<Map<String, dynamic>> getOrderRatingStatus(
    String orderId,
    String userId,
  ) async {
    final order = await _client
        .from('orders')
        .select(
          'consumer_id, rider_id, status, '
          'order_items(farmer_id), '
          'ratings(rater_id, rated_id, role_rated, score)',
        )
        .eq('id', orderId)
        .maybeSingle();

    if (order == null || order['status'] != 'delivered') {
      return {'canRate': <Map<String, dynamic>>[], 'alreadyRated': <Map<String, dynamic>>[]};
    }

    final consumerId = order['consumer_id'] as String?;
    final riderId = order['rider_id'] as String?;
    final orderItems = order['order_items'] as List? ?? [];
    final existingRatings = order['ratings'] as List? ?? [];

    // Collect unique farmer IDs from order items.
    final farmerIds = <String>{};
    for (final item in orderItems) {
      final farmerId = (item as Map<String, dynamic>)['farmer_id'] as String?;
      if (farmerId != null) farmerIds.add(farmerId);
    }

    // Determine possible rating targets based on user's role in the order.
    // Each target is {id, roleRated}.
    final targets = <Map<String, String>>[];

    if (userId == consumerId) {
      // Consumer can rate rider and farmers.
      if (riderId != null) {
        targets.add({'id': riderId, 'roleRated': 'rider'});
      }
      for (final fid in farmerIds) {
        targets.add({'id': fid, 'roleRated': 'farmer'});
      }
    } else if (userId == riderId) {
      // Rider can rate farmers.
      for (final fid in farmerIds) {
        targets.add({'id': fid, 'roleRated': 'farmer'});
      }
    } else if (farmerIds.contains(userId)) {
      // Farmer can rate rider.
      if (riderId != null) {
        targets.add({'id': riderId, 'roleRated': 'rider'});
      }
    }

    if (targets.isEmpty) {
      return {'canRate': <Map<String, dynamic>>[], 'alreadyRated': <Map<String, dynamic>>[]};
    }

    // Check which targets have already been rated by this user.
    final alreadyRatedSet = <String>{};
    final ratingScores = <String, int>{};
    for (final r in existingRatings) {
      final rating = r as Map<String, dynamic>;
      if (rating['rater_id'] == userId) {
        final key = '${rating['rated_id']}_${rating['role_rated']}';
        alreadyRatedSet.add(key);
        ratingScores[key] = rating['score'] as int;
      }
    }

    // Fetch names for all target user IDs.
    final targetIds = targets.map((t) => t['id']!).toSet().toList();
    final users = await _client
        .from('users')
        .select('id, name')
        .inFilter('id', targetIds);

    final nameMap = <String, String>{};
    for (final u in users) {
      nameMap[u['id'] as String] = (u['name'] as String?) ?? 'Unknown';
    }

    // Split targets into canRate vs alreadyRated.
    final canRate = <Map<String, dynamic>>[];
    final alreadyRated = <Map<String, dynamic>>[];

    for (final target in targets) {
      final key = '${target['id']}_${target['roleRated']}';
      final entry = <String, dynamic>{
        'id': target['id'],
        'name': nameMap[target['id']] ?? 'Unknown',
        'roleRated': target['roleRated'],
      };

      if (alreadyRatedSet.contains(key)) {
        entry['score'] = ratingScores[key];
        alreadyRated.add(entry);
      } else {
        canRate.add(entry);
      }
    }

    return {'canRate': canRate, 'alreadyRated': alreadyRated};
  }

  /// Get paginated ratings received by a user.
  Future<List<Map<String, dynamic>>> getUserRatings(
    String userId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final result = await _client
        .from('ratings')
        .select('*, rater:users!ratings_rater_id_fkey(id, name, avatar_url)')
        .eq('rated_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(result);
  }
}
