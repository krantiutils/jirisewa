import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';

const _kLocaleKey = 'jirisewa_locale';

/// Provider that manages the user's locale preference.
///
/// Reads from the user profile's `lang` field when authenticated,
/// falls back to SharedPreferences for offline caching,
/// and defaults to Nepali (`ne`) if nothing is set.
final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    // Check if the user has a profile with a language preference.
    final session = ref.watch(userSessionProvider).valueOrNull;
    final profileLang = session?.profile?.lang;

    if (profileLang != null && profileLang.isNotEmpty) {
      // Cache the profile language locally for offline access.
      _cacheLocale(profileLang);
      return Locale(profileLang);
    }

    // Fall back to cached locale from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kLocaleKey);
    if (cached != null && cached.isNotEmpty) {
      return Locale(cached);
    }

    // Default to Nepali.
    return const Locale('ne');
  }

  /// Change the locale. Updates SharedPreferences and (if authenticated)
  /// the user's `lang` field in the database.
  Future<void> setLocale(Locale locale) async {
    final langCode = locale.languageCode;

    // Update local cache immediately.
    state = AsyncData(locale);
    await _cacheLocale(langCode);

    // Update the database if the user is authenticated.
    final session = ref.read(userSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile != null) {
      try {
        final client = ref.read(supabaseProvider);
        await client
            .from('users')
            .update({'lang': langCode}).eq('id', profile.id);
      } catch (_) {
        // Silently fail — the cached value is already set.
      }
    }
  }

  Future<void> _cacheLocale(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, langCode);
  }
}
