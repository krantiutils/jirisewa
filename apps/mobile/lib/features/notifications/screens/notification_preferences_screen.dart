import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/notifications/providers/notification_provider.dart';

/// Per-category notification preferences screen.
///
/// Displays a toggle switch for each notification category. Changes are
/// persisted immediately via the repository and the local provider is
/// invalidated so other screens reflect the latest state.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
              child: Row(
                children: [
                  const BackButton(),
                  Text(
                    'Notification Preferences',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: preferencesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load preferences: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(notificationPreferencesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (preferences) => preferences.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No notification categories available',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: preferences.length,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemBuilder: (ctx, i) {
                          final pref = preferences[i];
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _humanReadableCategory(pref.category),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: pref.enabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: (enabled) async {
                              final profile =
                                  ref.read(userProfileProvider);
                              if (profile == null) return;

                              final repo =
                                  ref.read(notificationRepositoryProvider);
                              await repo.updatePreference(
                                profile.id,
                                pref.category,
                                enabled,
                              );
                              ref.invalidate(
                                  notificationPreferencesProvider);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Converts a snake_case category string to a human-readable title.
  ///
  /// For example, `'order_matched'` becomes `'Order Matched'`.
  static String _humanReadableCategory(String category) {
    return category
        .split('_')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
