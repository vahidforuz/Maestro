import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/students_screen.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';

class _StudentsApi implements MaestroDataSource {
  final students = <Student>[_student(1, 'Existing', 'PIANO')];
  int fetches = 0;
  Map<String, dynamic>? lastRequest;
  bool fail = false;
  Completer<void>? createGate;
  int createCalls = 0;

  @override
  Future<List<Student>> fetchStudents() async {
    fetches++;
    return List<Student>.of(students);
  }

  @override
  Future<Student> createStudent(Map<String, dynamic> request) async {
    createCalls++;
    await createGate?.future;
    lastRequest = request;
    if (fail) throw StateError('Create failed');
    final created = _student(2, 'New Student', request['instrument'] as String);
    students.add(created);
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Student _student(int id, String name, String instrument) => Student.fromJson({
      'id': id,
      'name': name,
      'teacherId': 7,
      'instrument': instrument,
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
  Future<void> showStudents(WidgetTester tester, _StudentsApi api,
      {Future<void> Function(int, String)? onInviteStudent}) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudentsScreen(
                api: api,
                teacher: const Teacher(id: 7, name: 'Teacher'),
                onInviteStudent: onInviteStudent,
                onOpenStudent: (_) {}))));
    await tester.pumpAndSettle();
  }

  testWidgets('custom instrument and picked time save and refresh once',
      (tester) async {
    final api = _StudentsApi();
    await showStudents(tester, api);
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.enterText(
        find.widgetWithText(TextField, 'Last name'), 'Student');
    await tester.tap(find.text('PIANO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTHER').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Custom instrument'), 'Oboe');
    await tester.tap(find.text('Course hour'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to text input mode'));
    await tester.pumpAndSettle();
    final pickerInputs = find.descendant(
        of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    expect(pickerInputs, findsNWidgets(2));
    await tester.enterText(pickerInputs.first, '17');
    await tester.enterText(pickerInputs.last, '30');
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(api.lastRequest?['instrument'], 'Oboe');
    expect(api.lastRequest?['courseHour'], '17:30');
    expect(api.fetches, 2);
    expect(find.text('New Student'), findsOneWidget);
    expect(find.text('Oboe - No level'), findsOneWidget);
  });

  testWidgets('failed creation leaves list unchanged', (tester) async {
    final api = _StudentsApi()..fail = true;
    await showStudents(tester, api);
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Create failed'), findsOneWidget);
    expect(api.fetches, 1);
    expect(api.students, hasLength(1));
  });

  testWidgets('student with email is invited after save only once',
      (tester) async {
    final api = _StudentsApi();
    final invites = <String>[];
    await showStudents(tester, api,
        onInviteStudent: (id, email) async => invites.add('$id:$email'));
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'new@maestro.example');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(api.students, hasLength(2));
    expect(invites, ['2:new@maestro.example']);
  });

  testWidgets('repeated create taps do not duplicate student or invitation',
      (tester) async {
    final api = _StudentsApi()..createGate = Completer<void>();
    var invites = 0;
    await showStudents(tester, api,
        onInviteStudent: (_, __) async => invites++);
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'new@maestro.example');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Create'))
            .onPressed,
        isNull);
    api.createGate!.complete();
    await tester.pumpAndSettle();
    expect(api.createCalls, 1);
    expect(invites, 1);
  });

  testWidgets('student without email is saved without invitation',
      (tester) async {
    final api = _StudentsApi();
    var invitations = 0;
    await showStudents(tester, api,
        onInviteStudent: (_, __) async => invitations++);
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(api.students, hasLength(2));
    expect(invitations, 0);
  });

  testWidgets('email failure keeps saved student and shows retry guidance',
      (tester) async {
    final api = _StudentsApi();
    await showStudents(tester, api,
        onInviteStudent: (_, __) async => throw StateError('mail failed'));
    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'New');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'new@maestro.example');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(api.students, hasLength(2));
    expect(find.textContaining('activation email could not be sent'),
        findsOneWidget);
  });
}
