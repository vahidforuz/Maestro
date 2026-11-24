import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/core/config/supabase_environment.dart';

void main() {
  const publicKey = 'sb_publishable_test';

  test('existing local web and Android definitions remain valid', () {
    for (final url in [
      'http://127.0.0.1:54321',
      'http://localhost:54321',
      'http://10.0.2.2:54321',
    ]) {
      SupabaseEnvironment.validateValues(
          name: 'local', url: url, publishableKey: publicKey);
    }
  });

  test('cloud staging accepts only the deployed HTTPS project', () {
    SupabaseEnvironment.validateValues(
        name: 'cloud-staging',
        url: 'https://jplmrmxibajrvrlhmvkp.supabase.co',
        publishableKey: publicKey);
    for (final url in [
      'http://127.0.0.1:54321',
      'https://other.supabase.co',
      'http://jplmrmxibajrvrlhmvkp.supabase.co',
    ]) {
      expect(
          () => SupabaseEnvironment.validateValues(
              name: 'cloud-staging', url: url, publishableKey: publicKey),
          throwsStateError);
    }
  });

  test('incomplete configuration and unknown environment fail', () {
    expect(
        () => SupabaseEnvironment.validateValues(
            name: 'local', url: 'http://127.0.0.1:54321', publishableKey: ''),
        throwsStateError);
    expect(
        () => SupabaseEnvironment.validateValues(
            name: 'production', url: '', publishableKey: ''),
        throwsStateError);
  });
}
