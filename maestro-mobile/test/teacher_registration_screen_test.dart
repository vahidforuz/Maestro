import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/screens/teacher_registration_screen.dart';
import 'package:maestro_mobile/services/teacher_auth.dart';

class _RegistrationAuth implements TeacherAuth {
  String? registeredEmail;

  @override
  bool get hasSession => false;
  @override
  String? get email => null;
  @override
  Stream<bool> get sessionChanges => const Stream.empty();
  @override
  Future<bool> canCreateTeacherProfile() async => false;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<bool> signUp(String email, String password) async {
    registeredEmail = email;
    return false;
  }
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('teacher registration requires names and matching passwords',
      (tester) async {
    final auth = _RegistrationAuth();
    await tester.binding.setSurfaceSize(const Size(700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: TeacherRegistrationScreen(auth: auth)));
    await tester.tap(find.text('Create Teacher Account').last);
    await tester.pump();
    expect(auth.registeredEmail, isNull);
    expect(find.textContaining('matching passwords'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'First Name'), 'Ada');
    await tester.enterText(find.widgetWithText(TextField, 'Last Name'), 'Lovelace');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'secret123');
    await tester.tap(find.text('Create Teacher Account').last);
    await tester.pump();
    expect(auth.registeredEmail, 'ada@example.com');
    expect(find.textContaining('Check your email to verify'), findsOneWidget);
  });
}
