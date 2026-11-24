/// Public client configuration supplied at build time with --dart-define.
/// Never put a service-role or secret key in a Flutter build.
class SupabaseEnvironment {
  /// Existing local define files omit this value, so local remains the default.
  static const name =
      String.fromEnvironment('MAESTRO_ENV', defaultValue: 'local');
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static void validate() {
    validateValues(name: name, url: url, publishableKey: publishableKey);
  }

  static void validateValues({
    required String name,
    required String url,
    required String publishableKey,
  }) {
    if (name != 'local' && name != 'cloud-staging') {
      throw StateError('MAESTRO_ENV must be local or cloud-staging.');
    }
    if (url.isEmpty != publishableKey.isEmpty) {
      throw StateError(
        'Set both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY, or neither.',
      );
    }
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.isNotEmpty && uri.path != '/') {
      throw StateError('SUPABASE_URL must be a Supabase API origin.');
    }
    if (name == 'local') {
      if (uri.scheme != 'http' ||
          !{'127.0.0.1', 'localhost', '10.0.2.2'}.contains(uri.host) ||
          uri.port != 54321) {
        throw StateError(
            'Local mode requires the local Supabase API on port 54321.');
      }
    } else if (uri.origin != 'https://jplmrmxibajrvrlhmvkp.supabase.co') {
      throw StateError(
          'Cloud staging mode requires the Maestro staging Supabase URL.');
    }
  }
}
