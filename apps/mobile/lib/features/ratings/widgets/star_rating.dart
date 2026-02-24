import 'package:flutter/material.dart';

/// Interactive 1-5 star rating widget.
///
/// When [onChanged] is non-null the stars are tappable and the widget acts as
/// an input control. When [onChanged] is null the widget is read-only and
/// simply displays the current [rating].
class StarRating extends StatelessWidget {
  /// Current rating value (1-5). A value of 0 means no stars are filled.
  final int rating;

  /// Called when the user taps a star. Pass null for read-only display.
  final ValueChanged<int>? onChanged;

  /// Size of each star icon.
  final double size;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;

        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(starIndex) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
