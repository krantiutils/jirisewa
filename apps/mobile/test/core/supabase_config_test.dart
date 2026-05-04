import 'package:flutter_test/flutter_test.dart';
import 'package:jirisewa_mobile/core/supabase_config.dart';

void main() {
  group('Supabase config', () {
    test('uses the production self-hosted endpoint by default', () {
      final config = getSupabaseConfig();

      expect(config.url, productionSupabaseUrl);
      expect(config.anonKey, productionSupabaseAnonKey);
      expect(config.anonKey.startsWith('eyJ'), isTrue);
    });

    test('trims configured values', () {
      final config = getSupabaseConfig(
        url: '  https://example.com/_supabase  ',
        anonKey: '  eyJ.test  ',
      );

      expect(config.url, 'https://example.com/_supabase');
      expect(config.anonKey, 'eyJ.test');
    });

    test('rejects an empty anon key', () {
      expect(() => getSupabaseConfig(anonKey: ''), throwsA(isA<StateError>()));
    });

    test('rejects hosted Supabase publishable keys', () {
      expect(
        () => getSupabaseConfig(anonKey: 'sb_publishable_bad'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects invalid URLs', () {
      expect(
        () => getSupabaseConfig(url: 'localhost:54321'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
