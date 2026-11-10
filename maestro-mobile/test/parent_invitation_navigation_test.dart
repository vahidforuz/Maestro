import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/portal_shell.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';
import 'package:maestro_mobile/services/teacher_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ParentAuth implements TeacherAuth {
  @override
  bool get hasSession => true;
  @override
  String? get email => 'parent@maestro.example';
  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();
  @override
  Future<bool> canCreateTeacherProfile() async => false;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<bool> signUp(String email, String password) async => false;
  @override
  Future<void> signOut() async {}
}

class _NoTeachers implements MaestroDataSource {
  @override
  Future<List<Teacher>> fetchTeachers() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('existing parent can accept another student invitation',
      (tester) async {
    var accepted = false;
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      final path = request.url.path;
      Object body;
      if (path.endsWith('/maestro_student_portal_data')) {
        body = [];
      } else if (path.endsWith('/maestro_parent_portal_data')) {
        body = [
          {
            'studentId': 'student-1',
            'studentName': 'Aria',
            'teacherName': 'Ada',
            'currency': 'CAD',
            'canViewFinances': true,
            'balance': 0,
            'fees': [],
            'payments': [],
          }
        ];
      } else if (path.endsWith('/maestro_accept_parent_invitation')) {
        expect(jsonDecode(request.body), {'p_token': 'new-invitation'});
        accepted = true;
        body = {'studentId': 'student-2'};
      } else if (path.endsWith('/maestro_conversation_summaries')) {
        body = [];
      } else {
        throw StateError('Unexpected request: $path');
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(
        home: PortalShell(
            client: client,
            api: _NoTeachers(),
            auth: _ParentAuth(),
            initialParentInvite: 'new-invitation')));
    await tester.pumpAndSettle();
    expect(find.text('Accept invitation'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Invitation token or link'))
            .controller!
            .text,
        'new-invitation');
    expect(accepted, isFalse);
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect(find.text('Linked students'), findsOneWidget);
  });
}
