import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/students_screen.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';
import 'package:maestro_mobile/services/messaging_inbox.dart';
import 'package:maestro_mobile/services/messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StudentsFixture implements MaestroDataSource {
  @override
  Future<List<Student>> fetchStudents() async => [
        _student(11, 'Ari Student'),
        _student(12, 'Bea Student'),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Student _student(int id, String name) => Student.fromJson({
      'id': id,
      'name': name,
      'teacherId': 7,
      'coursePrice': 0,
      'present': false,
      'firstCourseStatus': 'NOTHING',
      'nextWeekAssignment': '',
      'thisWeekComment': '',
      'paymentCreditBalance': 0,
      'courses': [],
      'projects': [],
    });

void main() {
  for (final width in [420.0, 810.0, 1280.0]) {
    testWidgets('student message buttons keep row actions at ${width}px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = SupabaseClient('https://example.invalid', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      final inbox = MessagingInbox(MessagingService(client));
      inbox.conversations = [
        {'studentId': 'student-a', 'unreadCount': 3},
        {'studentId': 'student-b', 'unreadCount': 0},
      ];
      final openedMessages = <(int, String?)>[];
      final openedProfiles = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentsScreen(
            api: _StudentsFixture(),
            teacher: const Teacher(id: 7, name: 'Teacher'),
            onOpenStudent: (student) => openedProfiles.add(student.id),
            onMessageStudent: (student, id) =>
                openedMessages.add((student.id, id)),
            loadMessageStudentIds: () async => {
              11: 'student-a',
              12: 'student-b',
            },
            inbox: inbox,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final ariButton = find.byKey(const ValueKey('message-student-11'));
      final beaButton = find.byKey(const ValueKey('message-student-12'));
      expect(ariButton, findsOneWidget);
      expect(beaButton, findsOneWidget);
      expect(find.descendant(of: ariButton, matching: find.text('3')),
          findsOneWidget);

      await tester.tap(beaButton);
      expect(openedMessages, [(12, 'student-b')]);
      expect(openedProfiles, isEmpty);

      inbox.conversations = [
        {'studentId': 'student-a', 'unreadCount': 4},
      ];
      inbox.notifyListeners();
      await tester.pump();
      expect(find.descendant(of: ariButton, matching: find.text('4')),
          findsOneWidget);

      await tester.tap(find.text('Ari Student'));
      expect(openedProfiles, [11]);
      inbox.dispose();
    });
  }
}
