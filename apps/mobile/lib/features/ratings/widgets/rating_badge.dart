import 'package:flutter/material.dart';

/// Compact inline widget that shows average rating and count.
///
/// Displays as "4.5 [star] (23)" when data is available, or "No ratings" when
/// [averageRating] is null or [ratingCount] is zero.
class RatingBadge extends StatelessWidget {
  /// Average rating value (e.g. 4.5). Null means no ratings yet.
  final double? averageRating;

  /// Total number of ratings. Null or zero means no ratings yet.
  final int? ratingCount;

  const RatingBadge({
    super.key,
    this.averageRating,
    this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    final hasRatings =
        averageRating != null && ratingCount != null && ratingCount! > 0;

    if (!hasRatings) {
      return Text(
        'No ratings',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          averageRating!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '($ratingCount)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
