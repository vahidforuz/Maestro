import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/screens/parent_portal_screen.dart';
import 'package:maestro_mobile/services/messaging_inbox.dart';
import 'package:maestro_mobile/services/messaging_service.dart';
import 'package:maestro_mobile/services/parent_portal_service.dart';
import 'package:maestro_mobile/widgets/dashboard_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ParentFixture extends ParentPortalService {
  _ParentFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async => [
        {
          'studentId': 'student-1',
          'studentName': 'Aria',
          'teacherName': 'Ada',
          'currency': 'CAD',
          'canViewFinances': true,
          'balance': 30,
          'fees': [
            {
              'title': 'Piano lesson',
              'date': '2026-11-03',
              'amount': 50,
              'status': 'PRESENT',
            }
          ],
          'payments': [
            {'date': '2026-11-02', 'amount': 20, 'method': 'CASH'}
          ],
        },
        {
          'studentId': 'student-2',
          'studentName': 'Leo',
          'teacherName': 'Ben',
          'currency': 'CAD',
          'canViewFinances': true,
          'balance': 15,
          'fees': [],
          'payments': [],
        },
      ];
}

class _QuietInbox extends MessagingInbox {
  _QuietInbox(SupabaseClient client) : super(MessagingService(client));

  @override
  void start() {
    loading = false;
  }
}

class _RefreshingParentFixture extends _ParentFixture {
  _RefreshingParentFixture(super.client);

  final nextLoad = Completer<List<Map<String, dynamic>>>();
  int loads = 0;

  @override
  Future<List<Map<String, dynamic>>> loadPortals() {
    loads++;
    return loads == 1 ? super.loadPortals() : nextLoad.future;
  }
}

class _EmptyParentFixture extends _ParentFixture {
  _EmptyParentFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async => [];
}

class _OneChildParentFixture extends _ParentFixture {
  _OneChildParentFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async =>
      [(await super.loadPortals()).first];
}

class _NoFinanceParentFixture extends _ParentFixture {
  _NoFinanceParentFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async => [
        {
          ...(await super.loadPortals()).first,
          'canViewFinances': false,
          'balance': null,
          'fees': [],
          'payments': [],
        }
      ];
}

void main() {
  testWidgets('parent sees combined balance and teacher-scoped payment rows',
      (tester) async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final inbox = _QuietInbox(client);
    addTearDown(inbox.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ParentPortalScreen(
            client: client,
            service: _ParentFixture(client),
            inbox: inbox,
            onSignOut: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Aria'), findsOneWidget);
    expect(find.text('Leo'), findsOneWidget);
    expect(find.text('45.00 CAD'), findsWidgets);
    expect(find.text('Quick actions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
    await tester.pumpAndSettle();
    expect(find.text('All my children'), findsOneWidget);
    expect(find.text('Aria · Ada'), findsOneWidget);
    expect(find.text('Leo · Ben'), findsOneWidget);
    expect(find.text('Piano lesson'), findsOneWidget);
    expect(find.text('20.00 CAD'), findsOneWidget);
    expect(find.text('Add payment'), findsNothing);
  });

  testWidgets('student selection and refresh hide stale payment details',
      (tester) async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final inbox = _QuietInbox(client);
    addTearDown(inbox.dispose);
    final service = _RefreshingParentFixture(client);
    await tester.pumpWidget(MaterialApp(
        home: ParentPortalScreen(
            client: client,
            service: service,
            inbox: inbox,
            onSignOut: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All my children'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leo').last);
    await tester.pumpAndSettle();
    expect(find.text('Piano lesson'), findsNothing);
    expect(find.text('20.00 CAD'), findsNothing);
    expect(find.text('15.00 CAD'), findsOneWidget);

    await tester.tap(find.text('Leo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All my children').last);
    await tester.pumpAndSettle();
    expect(find.text('45.00 CAD'), findsOneWidget);
    expect(find.text('Piano lesson'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.text('15.00 CAD'), findsNothing);
    service.nextLoad.complete([
      {
        'studentId': 'student-2',
        'studentName': 'Leo',
        'teacherName': 'Ben',
        'currency': 'CAD',
        'canViewFinances': true,
        'balance': 15,
        'fees': [],
        'payments': [],
      }
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Aria · Ada'), findsNothing);
    expect(find.text('Leo · Ben'), findsOneWidget);
  });

  testWidgets('parent without linked students sees an empty state',
      (tester) async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final inbox = _QuietInbox(client);
    addTearDown(inbox.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ParentPortalScreen(
            client: client,
            service: _EmptyParentFixture(client),
            inbox: inbox,
            onSignOut: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('No students linked to this account.'), findsOneWidget);
    expect(find.byKey(const ValueKey('shortcut-Payments')), findsNothing);
  });

  testWidgets('parent without finance grant has no payment shortcut',
      (tester) async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final inbox = _QuietInbox(client);
    addTearDown(inbox.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ParentPortalScreen(
            client: client,
            service: _NoFinanceParentFixture(client),
            inbox: inbox,
            onSignOut: () async {})));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcut-Payments')), findsNothing);
  });

  testWidgets('one-child selector has only the authorized child',
      (tester) async {
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    final inbox = _QuietInbox(client);
    addTearDown(inbox.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ParentPortalScreen(
            client: client,
            service: _OneChildParentFixture(client),
            inbox: inbox,
            onSignOut: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
    await tester.pumpAndSettle();
    expect(find.text('All my children'), findsOneWidget);
    expect(find.text('Aria · Ada'), findsOneWidget);
    expect(find.text('Leo · Ben'), findsNothing);
    await tester.tap(find.text('All my children'));
    await tester.pumpAndSettle();
    expect(find.text('Aria'), findsWidgets);
    expect(find.text('Leo'), findsNothing);
  });
}
