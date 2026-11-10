import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maestro_mobile/services/parent_portal_service.dart';
import 'package:maestro_mobile/services/student_portal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('student invitation uses backend delivery and can be retried', () async {
    final requests = <Map<String, dynamic>>[];
    var failFirst = true;
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      expect(request.url.path, '/functions/v1/send-invitation');
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (failFirst) {
        failFirst = false;
        return http.Response(jsonEncode({'error': 'Mail unavailable'}), 400,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
          jsonEncode({
            'token': 'retry-token',
            'delivered': true,
            'link': 'https://maestro.example/?invite=retry-token'
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = StudentPortalService(client);
    await expectLater(service.invite(11, 'student@maestro.example'),
        throwsA(isA<Exception>()));
    final result = await service.invite(11, 'student@maestro.example');
    expect(result['delivered'], true);
    expect(requests, [
      {'kind': 'student', 'studentId': 11, 'email': 'student@maestro.example'},
      {'kind': 'student', 'studentId': 11, 'email': 'student@maestro.example'},
    ]);
  });

  test('parent invitation sends authorized relationship details to backend',
      () async {
    Map<String, dynamic>? requestBody;
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({'token': 'parent-token', 'delivered': true}), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    await ParentPortalService(client)
        .invite(11, 'Pat Parent', 'pat@maestro.example');
    expect(requestBody, {
      'kind': 'parent',
      'studentId': 11,
      'name': 'Pat Parent',
      'email': 'pat@maestro.example',
      'relationship': 'Other',
    });
  });

  test(
      'gateway DNS failure creates a manual parent invitation without claiming delivery',
      () async {
    final paths = <String>[];
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/functions/v1/send-invitation') {
        return http.Response(
            jsonEncode({'message': 'name resolution failed'}), 503,
            headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, '/rest/v1/rpc/maestro_invite_parent');
      expect(jsonDecode(request.body), {
        'p_student_app_id': 11,
        'p_name': 'Pat Parent',
        'p_email': 'pat@maestro.example',
        'p_relationship': 'Other',
      });
      return http.Response(
          jsonEncode({'token': 'manual-token', 'invitationId': 'invite-1'}),
          200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final result = await ParentPortalService(client)
        .invite(11, 'Pat Parent', 'pat@maestro.example');
    expect(result['token'], 'manual-token');
    expect(result['delivered'], isFalse);
    expect(paths, [
      '/functions/v1/send-invitation',
      '/rest/v1/rpc/maestro_invite_parent'
    ]);
  });

  test('other function failures do not create a second invitation', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      requests++;
      expect(request.url.path, '/functions/v1/send-invitation');
      return http.Response(jsonEncode({'error': 'Mail unavailable'}), 400,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    await expectLater(
        ParentPortalService(client)
            .invite(11, 'Pat Parent', 'pat@maestro.example'),
        throwsA(isA<Exception>()));
    expect(requests, 1);
  });

  test('missing email configuration also offers manual parent delivery',
      () async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path == '/functions/v1/send-invitation') {
        return http.Response(
            jsonEncode({'error': 'Invitation email is not configured.'}), 400,
            headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, '/rest/v1/rpc/maestro_invite_parent');
      return http.Response(jsonEncode({'token': 'manual-token'}), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final result = await ParentPortalService(client)
        .invite(11, 'Pat Parent', 'pat@maestro.example');
    expect(result['token'], 'manual-token');
    expect(result['delivered'], isFalse);
  });
}
