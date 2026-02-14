import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums.dart';
import '../models/user_profile.dart';

/// Manages authentication state and user profile data.
class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _profile;
  bool _loading = true;
  StreamSubscription<AuthState>? _authSub;

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  bool get isLoggedIn => _supabase.auth.currentSession != null;
  String? get userId => _supabase.auth.currentUser?.id;

  bool hasRole(UserRole role) => _profile?.hasRole(role) ?? false;
  Set<UserRole> get roles => _profile?.roleSet ?? {};

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _profile = null;
        _loading = false;
        notifyListeners();
      }
    });

    if (_supabase.auth.currentSession != null) {
      loadProfile();
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final data = await _supabase
          .from('users')
          .select('*, user_roles(*)')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _profile = UserProfile.fromJson(data);
      } else {
        _profile = null;
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      _profile = null;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _profile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
