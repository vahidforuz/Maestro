import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:maestro_mobile/models/course_filter.dart';
import 'package:maestro_mobile/models/payment.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/screens/student_profile_screen.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';
import 'package:maestro_mobile/theme/maestro_theme.dart';

Map<String, dynamic> _course(int id, DateTime? date,
        {String status = 'NOTHING', List<Object> notes = const []}) =>
    {
      'id': id,
      'title': 'Course $id',
      'date': date == null ? null : DateFormat('yyyy-MM-dd').format(date),
      'price': 0,
      'status': status,
      'assignment': '',
      'comment': '',
      'homeworkNextLesson': '',
      'notes': notes,
    };

Student _student(List<Map<String, dynamic>> courses) => Student.fromJson({
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
          'pieces': <String>[],
          'courses': courses,
        }
      ],
    });

class _CountingDataSource implements MaestroDataSource {
  _CountingDataSource(this.student);

  final Student student;
  int fetches = 0;

  @override
  Future<Student> fetchStudent(int id) async {
    fetches++;
    return student;
  }

  @override
  Future<List<Payment>> fetchStudentPayments(int studentId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('filters use local calendar dates and keep original course numbers', () {
    final today = DateTime(2026, 10, 22);
    final student = _student([
      _course(5, DateTime(2026, 11, 5)), // review-created future course
      _course(1, DateTime(2026, 9, 30), status: 'PRESENT'),
      _course(4, DateTime(2026, 10, 26)),
      _course(2, DateTime(2026, 10, 19)),
      _course(3, DateTime(2026, 10, 22), status: 'ABSENT'),
      _course(6, null),
    ]);
    List<int> ids(CourseFilter filter, [DateTime? month]) =>
        filteredCourseListings(student, filter,
                today: today, month: month ?? DateTime(2026, 10))
            .map((entry) => entry.course.id)
            .toList();

    expect(ids(CourseFilter.all), [1, 2, 3, 4, 5, 6]);
    expect(ids(CourseFilter.current), [2, 3]);
    expect(ids(CourseFilter.month), [2, 3, 4]);
    expect(ids(CourseFilter.month, DateTime(2026, 11)), [5]);
    expect(ids(CourseFilter.upcoming), [4, 5]);
    expect(ids(CourseFilter.past), [3, 2, 1]);
    expect(student.courseNumberForId(1), 1);
    expect(student.courseNumberForId(5), 5);
    expect(defaultCourseFilter(student, today), CourseFilter.current);
    expect(
        defaultCourseFilter(
            _student([
              _course(5, DateTime(2026, 11, 5)),
            ]),
            today),
        CourseFilter.upcoming);
  });

  testWidgets('filter controls preserve notes and reviews without refetching',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final future = today.add(const Duration(days: 7));
    final note = {
      'id': 17,
      'piece': 'Etude',
      'comment': 'Review the melody',
      'reviewDate': DateFormat('yyyy-MM-dd').format(future),
      'reviewStatus': 'PENDING',
      'sourceCourseId': 1,
      'targetCourseId': 3,
    };
    final api = _CountingDataSource(_student([
      _course(3, future),
      _course(1, today.subtract(const Duration(days: 7)), notes: [note]),
      _course(2, today),
    ]));
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<void> show({Key? key}) async {
      await tester.pumpWidget(MaterialApp(
        theme: MaestroTheme.light(),
        home: Scaffold(
          body: StudentProfileScreen(
              key: key, api: api, studentId: 11, onBack: () {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show();
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(find.byKey(const ValueKey(1)), findsNothing);
    expect(find.byKey(const ValueKey(3)), findsNothing);
    expect(api.fetches, 1);

    await tester.tap(find.text('Cours à venir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(3)), findsOneWidget);
    expect(find.byTooltip('Scheduled review'), findsOneWidget);
    expect(find.text('Etude: Review the melody'), findsOneWidget);
    expect(api.fetches, 1);

    await tester.tap(find.text('Tous les cours'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey(1)),
            matching: find.text('Etude: Review the melody')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey(3)), matching: find.text('Course 3')),
        findsOneWidget);

    await tester.tap(find.text('Ce mois'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(api.fetches, 1);

    await show(key: const ValueKey('refreshed'));
    expect(api.fetches, 2);
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
  });

  testWidgets(
      'mobile filters show nearest upcoming course and weekly empty state',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final api = _CountingDataSource(_student([
      _course(2, today.add(const Duration(days: 14))),
      _course(1, today.add(const Duration(days: 7))),
    ]));
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: MaestroTheme.light(),
      home: Scaffold(
        body: StudentProfileScreen(api: api, studentId: 11, onBack: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 courses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cours actuel'));
    await tester.pumpAndSettle();
    expect(find.text('0 courses'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('No course scheduled this week.'), 100);
    expect(find.text('No course scheduled this week.'), findsOneWidget);
    expect(find.byKey(const ValueKey(1)), findsNothing);
    expect(api.fetches, 1);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cours à venir'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey(1)), 120);
    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
