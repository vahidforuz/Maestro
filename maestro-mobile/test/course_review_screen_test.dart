import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/payment.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/screens/student_profile_screen.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';
import 'package:maestro_mobile/theme/maestro_theme.dart';

const _sourceNote = {
  'id': 17,
  'piece': 'Etude',
  'comment': 'Practice the left hand slowly',
  'createdDate': '2026-10-22',
  'reviewWeeks': 2,
  'reviewDate': '2026-11-05',
  'reviewStatus': 'PENDING',
  'sourceCourseId': 1,
  'targetCourseId': 3,
};

Map<String, dynamic> _course(int id, String date, List<Object> notes) => {
      'id': id,
      'title': 'Course $id',
      'date': date,
      'day': 'THURSDAY',
      'price': 0,
      'status': 'NOTHING',
      'assignment': '',
      'comment': '',
      'homeworkNextLesson': '',
      'notes': notes,
    };

Student _student() {
  final courses = [
    _course(1, '2026-10-22', [_sourceNote]),
    _course(2, '2026-10-29', []),
    _course(3, '2026-11-05', []),
  ];
  return Student.fromJson({
    'id': 11,
    'name': 'Sam Student',
    'firstName': 'Sam',
    'familyName': 'Student',
    'coursePrice': 0,
    'present': false,
    'firstCourseStatus': 'NOTHING',
    'nextWeekAssignment': '',
    'thisWeekComment': '',
    'paymentCreditBalance': 0,
    'courses': courses,
    'projects': [
      {
        'id': 1,
        'name': 'Project 1',
        'paidCourseCount': 0,
        'pieces': ['Etude'],
        'courses': courses,
      }
    ],
  });
}

class _ReviewDataSource implements MaestroDataSource {
  int applyCalls = 0;

  @override
  Future<Student> fetchStudent(int id) async => _student();

  @override
  Future<List<Payment>> fetchStudentPayments(int studentId) async => [];

  @override
  Future<int> applyNotesToAllFutureWeeks(int studentId, int courseId) async {
    applyCalls++;
    return 2;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EditingDataSource implements MaestroDataSource {
  String? comment = 'Practice the left hand slowly';

  Student get student {
    final note = {
      ..._sourceNote,
      'comment': comment,
    };
    final courses = [
      _course(3, '2026-11-05', []),
      _course(1, '2026-10-22', comment == null ? [] : [note]),
      _course(2, '2026-10-29', []),
    ];
    return Student.fromJson({
      'id': 11,
      'name': 'Sam Student',
      'coursePrice': 0,
      'present': false,
      'firstCourseStatus': 'NOTHING',
      'nextWeekAssignment': '',
      'thisWeekComment': '',
      'paymentCreditBalance': 0,
      'courses': courses,
      'projects': [
        {
          'id': 1,
          'name': 'Project 1',
          'paidCourseCount': 0,
          'pieces': ['Etude'],
          'courses': courses,
        }
      ],
    });
  }

  @override
  Future<Student> fetchStudent(int id) async => student;

  @override
  Future<List<Payment>> fetchStudentPayments(int studentId) async => [];

  @override
  Future<Student> updateNote(int studentId, int projectId, int courseId,
      int noteId, Map<String, dynamic> request) async {
    comment = request['comment'] as String?;
    return student;
  }

  @override
  Future<Student> deleteNote(
      int studentId, int projectId, int courseId, int noteId) async {
    comment = null;
    return student;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('adding a later course preserves chronological numbers', () {
    final student = Student.fromJson({
      'courses': [
        _course(4, '2026-11-12', []),
        _course(2, '2026-10-29', []),
        _course(1, '2026-10-22', []),
        _course(3, '2026-11-05', []),
      ],
    });
    expect(student.courseNumberForId(1), 1);
    expect(student.courseNumberForId(2), 2);
    expect(student.courseNumberForId(3), 3);
    expect(student.courseNumberForId(4), 4);
  });

  testWidgets('course numbers use dates and note previews refresh after edits',
      (tester) async {
    final api = _EditingDataSource();
    expect(api.student.courseNumberForId(1), 1);
    expect(api.student.courseNumberForId(2), 2);
    expect(api.student.courseNumberForId(3), 3);
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: MaestroTheme.light(),
      home: Scaffold(
        body: StudentProfileScreen(
          api: api,
          studentId: 11,
          onBack: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final source = find.byKey(const ValueKey(1));
    expect(find.descendant(of: source, matching: find.text('Course 1')),
        findsOneWidget);
    expect(find.descendant(
        of: source,
        matching: find.text('Etude: Practice the left hand slowly')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey(3)),
        matching: find.text('Course 3')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey(3)),
        matching: find.text('Review')), findsOneWidget);

    await tester.tap(find.descendant(
        of: source, matching: find.text('Open Lesson')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: source, matching: find.byTooltip('Edit note')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Comment'),
        'Practice C major scale');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: source,
        matching: find.text('Etude: Practice C major scale')), findsOneWidget);

    await tester.tap(find.descendant(
        of: source, matching: find.byTooltip('Delete note')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: source,
        matching: find.text('Etude: Practice C major scale')), findsNothing);
  });

  testWidgets('scheduled review appears once in a yellow card on its week',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: MaestroTheme.light(),
      home: Scaffold(
        body: StudentProfileScreen(
          api: _ReviewDataSource(),
          studentId: 11,
          initialCourseId: 3,
          onBack: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Practice the left hand slowly'), findsOneWidget);
    final review = tester.widget<Container>(find
        .ancestor(
          of: find.text('Review'),
          matching: find.byType(Container),
        )
        .first);
    expect((review.decoration as BoxDecoration).color, MaestroColors.warningBg);
  });

  testWidgets('applying future notes asks for confirmation', (tester) async {
    final api = _ReviewDataSource();
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: MaestroTheme.light(),
      home: Scaffold(
        body: StudentProfileScreen(
          api: api,
          studentId: 11,
          initialCourseId: 1,
          onBack: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply to All Future Weeks'));
    await tester.pumpAndSettle();
    expect(api.applyCalls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.applyCalls, 0);

    await tester.tap(find.text('Apply to All Future Weeks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(api.applyCalls, 1);
  });
}
