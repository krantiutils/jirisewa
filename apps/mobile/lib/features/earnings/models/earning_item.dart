/// Aggregated earnings summary for a user.
class EarningsSummary {
  final double totalEarned;
  final double pendingBalance;
  final double settledBalance;
  final double totalWithdrawn;
  final double totalRequested;

  const EarningsSummary({
    this.totalEarned = 0,
    this.pendingBalance = 0,
    this.settledBalance = 0,
    this.totalWithdrawn = 0,
    this.totalRequested = 0,
  });

  /// Balance available for payout requests (pending minus already-requested).
  double get availableBalance => pendingBalance - totalRequested;
}

/// A single earning record (e.g. from a completed order).
class EarningItem {
  final String id;
  final String? orderId;
  final double amount;
  final String status; // pending, settled, withdrawn
  final String role;
  final DateTime createdAt;

  const EarningItem({
    required this.id,
    this.orderId,
    required this.amount,
    required this.status,
    required this.role,
    required this.createdAt,
  });

  factory EarningItem.fromMap(Map<String, dynamic> map) {
    return EarningItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending',
      role: map['role'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
