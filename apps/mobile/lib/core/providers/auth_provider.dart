import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

/// Streams Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.read(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// Current session, derived from auth state stream.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session;
});

/// Whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});
