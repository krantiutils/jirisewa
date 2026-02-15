import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

import 'mock_supabase.dart';
import 'test_data.dart';

/// Shared mock client used across all tests.
/// Created once and reused — SupabaseClient constructor is synchronous.
final SupabaseClient mockClient = createMockSupabaseClient();

/// Wraps a screen widget in the minimum widget tree needed for testing:
/// MaterialApp + SessionProvider with mock data.
Widget buildTestApp({
  required Widget child,
  UserProfile? profile,
  List<UserRoleDetails>? roles,
  String activeRole = 'consumer',
}) {
  final service = SessionService.forTesting(
    client: mockClient,
    session: testSession,
    profile: profile ?? testProfile,
    roles: roles ?? testRoles,
    activeRole: activeRole,
  );

  return MaterialApp(
    theme: buildAppTheme(),
    debugShowCheckedModeBanner: false,
    home: SessionProvider(
      service: service,
      child: child,
    ),
  );
}

/// Wraps a screen without SessionProvider — for screens that don't need it.
Widget buildBareTestApp({required Widget child}) {
  return MaterialApp(
    theme: buildAppTheme(),
    debugShowCheckedModeBanner: false,
    home: child,
  );
}
