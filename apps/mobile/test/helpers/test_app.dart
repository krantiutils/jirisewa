import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/l10n/app_localizations.dart';

import 'mock_supabase.dart';
import 'test_data.dart';

/// Shared mock client used across all tests.
/// Created once and reused — SupabaseClient constructor is synchronous.
final SupabaseClient mockClient = createMockSupabaseClient();

/// Wraps a screen widget in the minimum widget tree needed for testing:
/// ProviderScope with Riverpod overrides for session data.
Widget buildTestApp({
  required Widget child,
  UserProfile? profile,
  List<UserRoleDetails>? roles,
  String activeRole = 'consumer',
  List<Override> extraOverrides = const [],
}) {
  final testUserSession = UserSession(
    profile: profile ?? testProfile,
    roles: roles ?? testRoles,
  );

  return ProviderScope(
    overrides: [
      supabaseProvider.overrideWithValue(mockClient),
      userSessionProvider.overrideWith(() => _TestUserSessionNotifier(testUserSession)),
      activeRoleProvider.overrideWith(() => _TestActiveRoleNotifier(activeRole)),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );
}

/// Wraps a screen without session overrides — for screens that don't need it.
Widget buildBareTestApp({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );
}

class _TestUserSessionNotifier extends UserSessionNotifier {
  final UserSession _session;
  _TestUserSessionNotifier(this._session);

  @override
  Future<UserSession> build() async => _session;

  @override
  Future<void> refresh() async {}
}

class _TestActiveRoleNotifier extends ActiveRoleNotifier {
  final String _role;
  _TestActiveRoleNotifier(this._role);

  @override
  String build() => _role;

  @override
  void switchRole(String role) {
    state = role;
  }
}
