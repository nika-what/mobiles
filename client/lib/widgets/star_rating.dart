import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double? userRating;
  final Function(double) onRatingChanged;
  final double starSize;
  final Color? color;

  const StarRating({
    super.key,
    required this.rating,
    this.userRating,
    required this.onRatingChanged,
    this.starSize = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1.0;
            // Приоритет отдаем оценке пользователя, если она есть
            final ratingToShow = userRating ?? rating;
            final isFilled = starValue <= ratingToShow;
            
            return GestureDetector(
              onTap: () => onRatingChanged(starValue),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: starSize,
                  color: color ?? Colors.amber,
                ),
              ),
            );
          }),
        ),
        if (userRating != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ваша оценка: ${userRating!.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

