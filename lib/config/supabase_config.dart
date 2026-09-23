/// Supabase project for United Kites billing.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  static const _defaultUrl = 'https://lpaxfmvtlichxgmmyjus.supabase.co';

  /// Dashboard publishable key (anon). Passed to Supabase.initialize as publishableKey.
  static const _defaultAnonKey =
      'sb_publishable_6c-nwQs5xYWADcjsi63tgQ_Xfn9WQzA';

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
