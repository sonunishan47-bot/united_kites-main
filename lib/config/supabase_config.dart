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

  static const _defaultUrl = 'https://obtporpfzgkpqrdbqjsm.supabase.co';

  /// Dashboard anon JWT (header + payload + provided signature).
  static const _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9idHBvcnBmemdrcHFyZGJxanNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NTQzMjksImV4cCI6MjEwNDMyNDMyOX0.oN9HLgHuMFb-f1fPHSPWCFyyaqUakB_V8URk5Ax-3-k';

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
