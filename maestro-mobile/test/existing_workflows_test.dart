import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/payment.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/maestro_app.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';
import 'package:maestro_mobile/services/studio_metrics.dart';
import 'package:maestro_mobile/services/teacher_auth.dart';

const teacher = {
  'id': 7,
  'name': 'Ada Lovelace',
  'firstName': 'Ada',
  'lastName': 'Lovelace',
  'defaultLessonDuration': 45,
  'defaultLessonPrice': 20,
  'currency': 'CAD',
};

const course = {
  'id': 1,
  'title': 'First course',
  'date': '2026-10-26',
  'day': 'MONDAY',
  'hour': '16:00',
  'price': 20,
  'status': 'NOTHING',
  'assignment': '',
  'comment': '',
  'homeworkNextLesson': '',
  'notes': [],
};

const student = {
  'id': 11,
  'name': 'Sam Student',
  'firstName': 'Sam',
  'familyName': 'Student',
  'teacherId': 7,
  'instrument': 'PIANO',
  'level': 'BEGINNER',
  'courseDay': 'MONDAY',
  'courseHour': '16:00',
  'coursePrice': 20,
  'present': false,
  'firstCourseStatus': 'NOTHING',
  'nextWeekAssignment': '',
  'thisWeekComment': '',
  'paymentCreditBalance': 0,
  'projects': [
    {
      'id': 1,
      'name': 'Project 1',
      'paidCourseCount': 0,
      'pieces': ['Etude'],
      'courses': [course],
    },
  ],
  'courses': [course],
};

void main() {
  testWidgets('non-teacher account is blocked from teacher onboarding',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MaestroApp(
            api: _FakeDataSource(emptyTeachers: true),
            auth: _FakeAuth(canCreateProfile: false))));
    await tester.pumpAndSettle();
    expect(find.text('This account is not linked to a teacher profile.'),
        findsOneWidget);
    expect(find.text('Create Teacher Profile'), findsNothing);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('signed-out teacher sees login and enters dashboard',
      (tester) async {
    final auth = _FakeAuth(signedIn: false);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: MaestroApp(api: _FakeDataSource(), auth: auth)));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).at(0), 'ada.teacher@maestro.example');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(auth.hasSession, isTrue);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('teacher can reach student profile and existing sections',
      (tester) async {
    final api = _FakeDataSource();

    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(MaterialApp(home: MaestroApp(api: api, auth: _FakeAuth())));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.text('Students').last);
    await tester.pumpAndSettle();
    expect(find.text('Sam Student'), findsOneWidget);

    await tester.tap(find.text('Sam Student'));
    await tester.pumpAndSettle();
    expect(find.text('Projects / Pieces'), findsOneWidget);
    expect(find.text('Payments'), findsWidgets);
    expect(api.fetchedStudent, isTrue);
    expect(api.fetchedStudentPayments, isTrue);
  });

  test('display balance charges present and absent, not cancelled lessons', () {
    final parsed = Student.fromJson({
      ...student,
      'courses': [
        {...course, 'status': 'PRESENT'},
        {...course, 'id': 2, 'status': 'ABSENT'},
        {...course, 'id': 3, 'status': 'CANCELED'},
      ],
    });
    expect(paymentBalance(parsed, []), -40);
  });
}

class _FakeDataSource implements MaestroDataSource {
  _FakeDataSource({this.emptyTeachers = false});
  final bool emptyTeachers;
  bool fetchedStudent = false;
  bool fetchedStudentPayments = false;

  @override
  Future<List<Teacher>> fetchTeachers() async =>
      emptyTeachers ? [] : [Teacher.fromJson(teacher)];
  @override
  Future<List<Student>> fetchStudents() async => [Student.fromJson(student)];
  @override
  Future<Student> fetchStudent(int id) async {
    fetchedStudent = true;
    return Student.fromJson(student);
  }

  @override
  Future<List<Payment>> fetchPayments() async => [];
  @override
  Future<List<Payment>> fetchStudentPayments(int studentId) async {
    fetchedStudentPayments = true;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements TeacherAuth {
  _FakeAuth({bool signedIn = true, this.canCreateProfile = true})
      : _signedIn = signedIn;
  bool _signedIn;
  final bool canCreateProfile;
  @override
  bool get hasSession => _signedIn;
  @override
  String? get email => 'ada.teacher@maestro.example';
  @override
  Stream<bool> get sessionChanges => const Stream.empty();
  @override
  Future<bool> canCreateTeacherProfile() async => canCreateProfile;
  @override
  Future<void> signIn(String email, String password) async {
    _signedIn = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
