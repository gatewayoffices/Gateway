/// Connection details for Supabase, read at build time from `env.json`:
///
///   flutter run --dart-define-from-file=env.json
///
/// `env.json` is git-ignored (see `env.example.json`). Without it the app
/// runs on the built-in sample data.
class BackendConfig {
  const BackendConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.googleSignIn,
  });

  static const fromEnvironment = BackendConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    googleSignIn: bool.fromEnvironment('GOOGLE_SIGN_IN'),
  );

  final String supabaseUrl;

  /// The project's publishable ("anon") key. It is designed to be inside the
  /// app; the database's security rules protect the data. Never put the
  /// secret ("service_role") key here.
  final String supabaseKey;

  /// Show "Continue with Google" (turn on once Google is set up in Supabase).
  final bool googleSignIn;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
