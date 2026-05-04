const productionSupabaseUrl = 'https://khetbata.xyz/_supabase';

const productionSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.'
    'CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const configuredSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: productionSupabaseUrl,
);

const configuredSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: productionSupabaseAnonKey,
);

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;
}

SupabaseConfig getSupabaseConfig({
  String url = configuredSupabaseUrl,
  String anonKey = configuredSupabaseAnonKey,
}) {
  final normalizedUrl = url.trim();
  final normalizedAnonKey = anonKey.trim();

  final parsedUrl = Uri.tryParse(normalizedUrl);
  if (normalizedUrl.isEmpty ||
      parsedUrl == null ||
      !parsedUrl.hasScheme ||
      !parsedUrl.hasAuthority) {
    throw StateError('SUPABASE_URL must be an absolute http(s) URL.');
  }

  if (normalizedAnonKey.isEmpty) {
    throw StateError('SUPABASE_ANON_KEY must be configured and non-empty.');
  }

  if (normalizedAnonKey.startsWith('sb_publishable_')) {
    throw StateError(
      'SUPABASE_ANON_KEY must be the self-hosted Kong anon JWT, not a '
      'Supabase publishable key.',
    );
  }

  return SupabaseConfig(url: normalizedUrl, anonKey: normalizedAnonKey);
}
