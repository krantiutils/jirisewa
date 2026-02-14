import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/models/user_profile.dart';

/// Manages authentication state, user profile, roles, and active role.
///
/// Implements [ChangeNotifier] so it can be used as [GoRouter.refreshListenable]
/// and drive UI rebuilds when auth/role state changes.
class SessionService extends ChangeNotifier {
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;

  Session? _session;
  UserProfile? _profile;
  List<UserRoleDetails> _roles = [];
  String _activeRole = 'consumer';
  bool _loading = true;
  String? _error;

  /// Monotonic counter to abort stale profile fetches. Each call to
  /// [_fetchProfile] captures the current value; if a newer fetch starts
  /// before the previous one finishes, the older one silently discards
  /// its results.
  int _fetchVersion = 0;

  SessionService(this._client) {
    _init();
  }

  // -- Public getters --

  bool get loading => _loading;
  bool get isAuthenticated => _session != null;
  bool get hasProfile => _profile != null;
  Session? get session => _session;
  UserProfile? get profile => _profile;
  List<UserRoleDetails> get roles => List.unmodifiable(_roles);
  String get activeRole => _activeRole;
  String? get error => _error;
  User? get user => _session?.user;

  bool get isConsumer => _activeRole == 'consumer';
  bool get isRider => _activeRole == 'rider';
  bool get isFarmer => _activeRole == 'farmer';
  bool get hasMultipleRoles => _roles.length > 1;

  UserRoleDetails? get activeRoleDetails {
    for (final r in _roles) {
      if (r.role == _activeRole) return r;
    }
    return null;
  }

  // -- Initialization --

  void _init() {
    _session = _client.auth.currentSession;
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthChange);

    if (_session != null) {
      _fetchProfile();
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  void _onAuthChange(AuthState state) {
    final newSession = state.session;
    final hadSession = _session != null;
    _session = newSession;

    if (newSession != null && !hadSession) {
      // Signed in — fetch profile. Any pending fetch is implicitly aborted
      // by the version counter bump inside _fetchProfile.
      _fetchProfile();
    } else if (newSession == null && hadSession) {
      // Signed out — clear everything and abort any in-flight fetch.
      _fetchVersion++;
      _profile = null;
      _roles = [];
      _activeRole = 'consumer';
      _loading = false;
      notifyListeners();
    }
  }

  // -- Profile fetching --

  Future<void> _fetchProfile() async {
    final userId = _session?.user.id;
    if (userId == null) return;

    final version = ++_fetchVersion;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final profileResponse = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // Abort if a newer fetch was started while we were waiting.
      if (version != _fetchVersion) return;

      if (profileResponse == null) {
        // Authenticated but hasn't completed registration yet.
        _profile = null;
        _roles = [];
        _loading = false;
        notifyListeners();
        return;
      }

      final fetchedProfile = UserProfile.fromMap(profileResponse);

      final rolesResponse = await _client
          .from('user_roles')
          .select()
          .eq('user_id', userId);

      if (version != _fetchVersion) return;

      _profile = fetchedProfile;
      _roles = (rolesResponse as List)
          .map((r) => UserRoleDetails.fromMap(r as Map<String, dynamic>))
          .toList();

      // Set active role: prefer the primary role from the users table,
      // fall back to the first role in user_roles, then 'consumer'.
      if (_roles.isNotEmpty) {
        final primaryRole = _profile!.role;
        final hasRole = _roles.any((r) => r.role == primaryRole);
        _activeRole = hasRole ? primaryRole : _roles.first.role;
      } else {
        _activeRole = _profile!.role;
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      if (version != _fetchVersion) return;
      _error = 'Failed to load profile: $e';
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh profile and roles from the database.
  Future<void> refreshProfile() async {
    await _fetchProfile();
  }

  // -- Role switching --

  /// Switch the active role. Only allowed if the user has the target role.
  void switchRole(String role) {
    if (_roles.any((r) => r.role == role) && role != _activeRole) {
      _activeRole = role;
      notifyListeners();
    }
  }

  // -- Profile updates --

  /// Update user profile fields in Supabase and refresh local state.
  Future<void> updateProfile({
    String? name,
    String? address,
    String? municipality,
    String? lang,
  }) async {
    final userId = _session?.user.id;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (address != null) updates['address'] = address;
    if (municipality != null) updates['municipality'] = municipality;
    if (lang != null) updates['lang'] = lang;

    if (updates.isEmpty) return;

    await _client.from('users').update(updates).eq('id', userId);
    await _fetchProfile();
  }

  // -- Sign out --

  Future<void> signOut() async {
    await _client.auth.signOut();
    // _onAuthChange will handle clearing state.
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// InheritedWidget to provide [SessionService] down the widget tree.
class SessionProvider extends InheritedNotifier<SessionService> {
  const SessionProvider({
    super.key,
    required SessionService service,
    required super.child,
  }) : super(notifier: service);

  static SessionService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SessionProvider>();
    if (provider?.notifier == null) {
      throw StateError('No SessionProvider found in widget tree');
    }
    return provider!.notifier!;
  }

  /// Read without subscribing to changes.
  static SessionService read(BuildContext context) {
    final provider =
        context.getInheritedWidgetOfExactType<SessionProvider>();
    if (provider?.notifier == null) {
      throw StateError('No SessionProvider found in widget tree');
    }
    return provider!.notifier!;
  }
}
