import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/earnings/models/earning_item.dart';
import 'package:jirisewa_mobile/features/earnings/repositories/earnings_repository.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(supabaseProvider));
});

final earningsSummaryProvider = FutureProvider.autoDispose<EarningsSummary>((ref) async {
  final repo = ref.watch(earningsRepositoryProvider);
  final profile = ref.watch(userProfileProvider);
  if (profile == null) return const EarningsSummary();
  return repo.getSummary(profile.id);
});

final earningsListProvider = FutureProvider.autoDispose.family<List<EarningItem>, int>(
  (ref, page) async {
    final repo = ref.watch(earningsRepositoryProvider);
    final profile = ref.watch(userProfileProvider);
    if (profile == null) return const [];
    return repo.listEarnings(profile.id, page: page);
  },
);
