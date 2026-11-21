/// Build-time configuration. Values come from
/// `--dart-define-from-file=../../env/dev.json` (see env/README.md).
/// Only the anon key is ever used in the apps.
abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
