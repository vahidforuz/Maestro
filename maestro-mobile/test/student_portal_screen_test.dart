import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/screens/student_portal_screen.dart';
import 'package:maestro_mobile/services/student_portal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PortalFixture extends StudentPortalService {
  _PortalFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async => [
        {
          'teacherId': 'teacher-1',
          'teacherName': 'Ada',
          'studentName': 'Aria',
          'permissions': {
            'viewCourses': true,
            'viewNotes': true,
            'viewReviews': true,
            'viewPieces': true,
            'viewPayments': false,
            'viewBalance': false,
          },
          'courses': [
            {
              'id': 'lesson-1',
              'title': 'Piano lesson',
              'date': '2026-11-01',
              'hour': '16:00',
              'durationMinutes': 60,
              'status': 'NOTHING',
            }
          ],
          'notes': [
            {
              'id': 'shared-note',
              'courseId': 'lesson-1',
              'piece': 'C major',
              'comment': 'Practice slowly',
              'createdDate': '2026-10-24',
              'reviewDate': null,
            },
            {
              'id': 'private-review',
              'courseId': 'lesson-1',
              'piece': null,
              'comment': null,
              'createdDate': '2026-10-24',
              'reviewDate': '2026-11-01',
            },
          ],
          'pieces': [],
          'payments': [],
          'balance': null,
        }
      ];
}

class _PaymentPortalFixture extends _PortalFixture {
  _PaymentPortalFixture(super.client);

  @override
  Future<List<Map<String, dynamic>>> loadPortals() async {
    final portals = await super.loadPortals();
    portals.first['permissions'] = {
      ...(portals.first['permissions'] as Map<String, dynamic>),
      'viewPayments': true,
    };
    return portals;
  }
}

void main() {
  testWidgets('mobile student navigation shows only shared note content',
      (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    await tester.pumpWidget(MaterialApp(
      home: StudentPortalScreen(
        client: client,
        service: _PortalFixture(client),
        onSignOut: () {},
        onSwitchTeacher: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Aria'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Practice Videos'), findsOneWidget);
    expect(find.byKey(const ValueKey('shortcut-Payments')), findsNothing);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcut-Pieces / Projects')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('shortcut-Payments')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lesson Notes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Practice slowly'), findsOneWidget);
    expect(find.textContaining('private-review'), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Payments'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Lesson Notes'), findsNothing);
  });

  testWidgets('authorized student payment shortcut opens existing page',
      (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient('https://example.invalid', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    await tester.pumpWidget(MaterialApp(
      home: StudentPortalScreen(
        client: client,
        service: _PaymentPortalFixture(client),
        onSignOut: () {},
        onSwitchTeacher: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
    await tester.pumpAndSettle();
    expect(find.text('Payments'), findsWidgets);
  });
}
