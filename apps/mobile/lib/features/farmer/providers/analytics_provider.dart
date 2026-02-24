import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/farmer/providers/farmer_provider.dart';

/// Provider that fetches farmer analytics data for a given time period (days).
final farmerAnalyticsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>(
  (ref, days) async {
    final repo = ref.watch(farmerRepositoryProvider);
    final profile = ref.watch(userProfileProvider);
    if (profile == null) return {};
    return repo.getAnalytics(profile.id, days: days);
  },
);
