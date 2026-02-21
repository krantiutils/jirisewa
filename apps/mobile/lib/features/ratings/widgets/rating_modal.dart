import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/ratings/providers/rating_provider.dart';
import 'package:jirisewa_mobile/features/ratings/widgets/star_rating.dart';

/// Bottom sheet modal for submitting a rating.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (ctx) => RatingModal(
///     orderId: orderId,
///     ratedId: userId,
///     ratedName: 'Ram Bahadur',
///     roleRated: 'farmer',
///   ),
/// );
/// ```
class RatingModal extends ConsumerStatefulWidget {
  final String orderId;
  final String ratedId;
  final String ratedName;
  final String roleRated;

  const RatingModal({
    super.key,
    required this.orderId,
    required this.ratedId,
    required this.ratedName,
    required this.roleRated,
  });

  @override
  ConsumerState<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends ConsumerState<RatingModal> {
  int _score = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score < 1) return;

    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(ratingRepositoryProvider);
      await repo.submitRating(
        orderId: widget.orderId,
        raterId: profile.id,
        ratedId: widget.ratedId,
        roleRated: widget.roleRated,
        score: _score,
        comment: _commentController.text.trim(),
      );

      // Invalidate providers so the UI refreshes.
      ref.invalidate(orderRatingStatusProvider(widget.orderId));
      ref.invalidate(userRatingsProvider(widget.ratedId));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Rate ${widget.ratedName}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Star rating
          Center(
            child: StarRating(
              rating: _score,
              onChanged: (value) => setState(() => _score = value),
              size: 36,
            ),
          ),
          if (_score < 1) ...[
            const SizedBox(height: 8),
            Text(
              'Tap a star to rate',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),

          // Comment field
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Add a comment (optional)',
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          ElevatedButton(
            onPressed: _score >= 1 && !_isSubmitting ? _submit : null,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Rating'),
          ),
        ],
      ),
    );
  }
}
