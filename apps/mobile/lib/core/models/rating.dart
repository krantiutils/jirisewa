import '../enums.dart';

class Rating {
  final String id;
  final String orderId;
  final String raterId;
  final String ratedId;
  final UserRole roleRated;
  final int score;
  final String? comment;
  final DateTime createdAt;

  // Joined fields
  final String? raterName;
  final String? ratedName;

  const Rating({
    required this.id,
    required this.orderId,
    required this.raterId,
    required this.ratedId,
    required this.roleRated,
    required this.score,
    this.comment,
    required this.createdAt,
    this.raterName,
    this.ratedName,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    final raterData = json['rater'] as Map<String, dynamic>?;
    final ratedData = json['rated'] as Map<String, dynamic>?;

    return Rating(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      raterId: json['rater_id'] as String,
      ratedId: json['rated_id'] as String,
      roleRated: UserRole.fromString(json['role_rated'] as String? ?? 'farmer'),
      score: json['score'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      raterName: raterData?['name'] as String?,
      ratedName: ratedData?['name'] as String?,
    );
  }
}
