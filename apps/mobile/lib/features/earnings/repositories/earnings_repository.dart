import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/features/earnings/models/earning_item.dart';

class EarningsRepository {
  final SupabaseClient _client;
  EarningsRepository(this._client);

  static const _perPage = 20;

  /// Fetch an aggregated earnings summary for the given user.
  ///
  /// Queries the `earnings` table for pending/settled amounts and the
  /// `payout_requests` table for withdrawn/requested amounts.
  Future<EarningsSummary> getSummary(String userId) async {
    // Fetch all earnings rows for this user.
    final earningsRows = await _client
        .from('earnings')
        .select('amount, status')
        .eq('user_id', userId);

    double pending = 0;
    double settled = 0;

    for (final row in earningsRows) {
      final map = Map<String, dynamic>.from(row);
      final amount = (map['amount'] as num?)?.toDouble() ?? 0;
      final status = map['status'] as String? ?? '';
      if (status == 'pending') {
        pending += amount;
      } else if (status == 'settled') {
        settled += amount;
      }
    }

    // Fetch payout request totals.
    final payoutRows = await _client
        .from('payout_requests')
        .select('amount, status')
        .eq('user_id', userId);

    double withdrawn = 0;
    double requested = 0;

    for (final row in payoutRows) {
      final map = Map<String, dynamic>.from(row);
      final amount = (map['amount'] as num?)?.toDouble() ?? 0;
      final status = map['status'] as String? ?? '';
      if (status == 'completed') {
        withdrawn += amount;
      } else if (status == 'pending') {
        requested += amount;
      }
    }

    return EarningsSummary(
      totalEarned: pending + settled + withdrawn,
      pendingBalance: pending,
      settledBalance: settled,
      totalWithdrawn: withdrawn,
      totalRequested: requested,
    );
  }

  /// List earnings for the given user with pagination and optional status filter.
  ///
  /// Returns [_perPage] items per page, ordered by most recent first.
  Future<List<EarningItem>> listEarnings(
    String userId, {
    int page = 1,
    String? statusFilter,
  }) async {
    final offset = (page - 1) * _perPage;

    var query = _client
        .from('earnings')
        .select()
        .eq('user_id', userId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + _perPage - 1);

    return rows
        .map((row) => EarningItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Submit a payout request for the given user.
  Future<void> requestPayout({
    required String userId,
    required double amount,
    required String method,
    String? accountDetails,
  }) async {
    await _client.from('payout_requests').insert({
      'user_id': userId,
      'amount': amount,
      'method': method,
      'account_details': accountDetails,
      'status': 'pending',
    });
  }
}
