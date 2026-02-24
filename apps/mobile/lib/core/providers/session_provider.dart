import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/providers/auth_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

/// Combined user profile + roles data.
class UserSession {
  final UserProfile? profile;
  final List<UserRoleDetails> roles;

  const UserSession({this.profile, this.roles = const []});

  bool get hasProfile => profile != null;
  bool get hasMultipleRoles => roles.length > 1;
}

/// Async provider that fetches user profile + roles when authenticated.
/// Automatically re-fetches when auth state changes (via currentSessionProvider dependency).
final userSessionProvider =
    AsyncNotifierProvider<UserSessionNotifier, UserSession>(
  UserSessionNotifier.new,
);

class UserSessionNotifier extends AsyncNotifier<UserSession> {
  @override
  Future<UserSession> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const UserSession();

    final client = ref.read(supabaseProvider);
    final userId = session.user.id;

    final profileResponse = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profileResponse == null) {
      return const UserSession();
    }

    final profile = UserProfile.fromMap(profileResponse);

    final rolesResponse =
        await client.from('user_roles').select().eq('user_id', userId);

    final roles = (rolesResponse as List)
        .map((r) => UserRoleDetails.fromMap(r as Map<String, dynamic>))
        .toList();

    return UserSession(profile: profile, roles: roles);
  }

  /// Force re-fetch of profile and roles from database.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Active role state (consumer/rider/farmer).
final activeRoleProvider =
    NotifierProvider<ActiveRoleNotifier, String>(ActiveRoleNotifier.new);

class ActiveRoleNotifier extends Notifier<String> {
  @override
  String build() {
    final session = ref.watch(userSessionProvider).valueOrNull;
    if (session == null || session.profile == null) return 'consumer';

    final roles = session.roles;
    final primaryRole = session.profile!.role;

    if (roles.isNotEmpty) {
      final hasRole = roles.any((r) => r.role == primaryRole);
      return hasRole ? primaryRole : roles.first.role;
    }
    return primaryRole;
  }

  void switchRole(String role) {
    final session = ref.read(userSessionProvider).valueOrNull;
    if (session == null) return;
    if (session.roles.any((r) => r.role == role)) {
      state = role;
    }
  }
}

/// Convenience providers for common access patterns.
final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.profile;
});

final userRolesProvider = Provider<List<UserRoleDetails>>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.roles ?? const [];
});

final isRiderProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'rider';
});

final isFarmerProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'farmer';
});

final isConsumerProvider = Provider<bool>((ref) {
  return ref.watch(activeRoleProvider) == 'consumer';
});

final hasMultipleRolesProvider = Provider<bool>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.hasMultipleRoles ?? false;
});

final hasProfileProvider = Provider<bool>((ref) {
  return ref.watch(userSessionProvider).valueOrNull?.hasProfile ?? false;
});
