import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

/// Streams Supabase auth state changes.
///
/// Note: `onAuthStateChange` does NOT replay the current session on
/// subscription — it only emits NEW events (signin/signout/token refresh).
/// So after a cold start with a restored session, this stream stays in
/// `loading` until the next auth event. Use [currentSessionProvider] to
/// observe the current session — it falls back to `auth.currentSession`
/// while the stream hasn't emitted yet.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.read(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// Current session, derived from auth state stream with fallback to the
/// already-restored session from local storage. Without the fallback, the
/// app would think no one was signed in until the next auth event.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  final fromStream = authState.valueOrNull?.session;
  if (fromStream != null) return fromStream;
  // Stream hasn't emitted yet (cold start with restored session) — read
  // the current session synchronously from the Supabase client.
  return ref.read(supabaseProvider).auth.currentSession;
});

/// Whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});
