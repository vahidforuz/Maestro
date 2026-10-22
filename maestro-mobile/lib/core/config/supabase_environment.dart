/// Public client configuration supplied at build time with --dart-define.
/// Never put a service-role or secret key in a Flutter build.
class SupabaseEnvironment {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static void validate() {
    if (url.isEmpty != publishableKey.isEmpty) {
      throw StateError(
        'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or neither.',
      );
    }
  }
}
