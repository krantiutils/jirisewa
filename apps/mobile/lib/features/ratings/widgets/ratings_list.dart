import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/ratings/providers/rating_provider.dart';
import 'package:jirisewa_mobile/features/ratings/widgets/star_rating.dart';

/// Paginated list of ratings received by a user.
///
/// Displays each rating as a card with the rater's name, star score,
/// optional comment, and relative timestamp.
class RatingsList extends ConsumerWidget {
  final String userId;

  const RatingsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingsAsync = ref.watch(userRatingsProvider(userId));

    return ratingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load ratings: $error',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (ratings) {
        if (ratings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No ratings yet',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ratings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return _RatingCard(rating: rating);
          },
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Map<String, dynamic> rating;

  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final rater = rating['rater'] as Map<String, dynamic>?;
    final raterName = (rater?['name'] as String?) ?? 'Unknown';
    final score = (rating['score'] as num?)?.toInt() ?? 0;
    final comment = rating['comment'] as String?;
    final createdAt = rating['created_at'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rater name and time
            Row(
              children: [
                Expanded(
                  child: Text(
                    raterName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatRelativeTime(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Stars
            StarRating(rating: score, size: 16),

            // Comment
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                comment,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format an ISO 8601 timestamp as a relative time string.
  String _formatRelativeTime(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) return '${difference.inDays ~/ 7}w ago';
      return '${difference.inDays ~/ 30}mo ago';
    } catch (_) {
      return '';
    }
  }
}
