import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/screens/student_access_screen.dart';
import 'package:maestro_mobile/services/student_portal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AccessFixture extends StudentPortalService {
  _AccessFixture(super.client);

  final invitation = Completer<Map<String, dynamic>>();
  int inviteCalls = 0;
  int loadCalls = 0;
  int? lastStudentId;
  String? lastEmail;
  bool failInvitation = false;

  @override
  Future<Map<String, dynamic>> loadAccess(int studentAppId) async {
    loadCalls++;
    return {'access': null, 'invitations': <dynamic>[], 'pieces': <dynamic>[]};
  }

  @override
  Future<Map<String, dynamic>> invite(int studentAppId, String email) {
    inviteCalls++;
    lastStudentId = studentAppId;
    lastEmail = email;
    if (failInvitation) throw Exception('Invitation request failed');
    return invitation.future;
  }
}

void main() {
  late SupabaseClient client;
  late _AccessFixture service;

  setUp(() {
    client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    service = _AccessFixture(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  Future<void> showAccess(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudentAccessScreen(studentId: 11, service: service))));
    await tester.pumpAndSettle();
  }

  testWidgets('invitation is submitted once and its token can be copied',
      (tester) async {
    await showAccess(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<String, dynamic>)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.enterText(
        find.byType(TextField).first, 'aria.student@maestro.example');
    await tester.tap(find.text('Create invitation'));
    await tester.pump();

    expect(service.inviteCalls, 1);
    expect(service.lastStudentId, 11);
    expect(service.lastEmail, 'aria.student@maestro.example');
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create invitation'))
            .onPressed,
        isNull);

    await tester.runAsync(() async {
      service.invitation.complete({'token': 'invite-123'});
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Invitation ready'), findsOneWidget);
    expect(find.text('invite-123'), findsOneWidget);

    await tester.tap(find.text('Copy token'));
    await tester.pump();
    expect(copied, 'invite-123');
    expect(find.text('Invitation token copied'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(service.loadCalls, 2);
    expect(service.inviteCalls, 1);
  });

  testWidgets('invitation failure is shown and permits a retry',
      (tester) async {
    await showAccess(tester);
    await tester.tap(find.text('Create invitation'));
    await tester.pump();
    expect(find.text('Enter a student email address.'), findsOneWidget);
    expect(service.inviteCalls, 0);

    await tester.enterText(
        find.byType(TextField).first, 'aria.student@maestro.example');
    service.failInvitation = true;
    await tester.tap(find.text('Create invitation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Invitation request failed'), findsOneWidget);
    expect(service.loadCalls, 1);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create invitation'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
}
