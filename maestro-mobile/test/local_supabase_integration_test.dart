import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/core/config/supabase_environment.dart';
import 'package:maestro_mobile/services/supabase_maestro_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final uri = Uri.tryParse(SupabaseEnvironment.url);
  final local = uri != null &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
      uri.port == 54321 &&
      SupabaseEnvironment.publishableKey.isNotEmpty;

  test('two local teachers load only their Supabase records',
      skip: !local ? 'Requires the local Supabase public defines' : null,
      () async {
    Future<(Set<int>, Set<int>)> readAs(String email) async {
      final client = SupabaseClient(
          SupabaseEnvironment.url, SupabaseEnvironment.publishableKey);
      try {
        await client.auth
            .signInWithPassword(email: email, password: 'LocalMaestro123!');
        final api = SupabaseMaestroDataSource(client);
        final teachers = await api.fetchTeachers();
        expect(teachers, hasLength(1));
        final students = await api.fetchStudents();
        final payments = await api.fetchPayments();
        expect(
            students
                .every((student) => student.teacherId == teachers.single.id),
            isTrue);
        expect(
            students.every((student) => student.projects.isNotEmpty), isTrue);
        return (
          students.map((student) => student.id).toSet(),
          payments.map((payment) => payment.id).toSet(),
        );
      } finally {
        await client.dispose();
      }
    }

    final ada = await readAs('ada.teacher@maestro.example');
    final ben = await readAs('ben.teacher@maestro.example');
    expect(ada.$1, {11, 12, 15});
    expect(ben.$1, {13, 14, 15});
    expect(ada.$2, {201});
    expect(ben.$2, {202});
  });
}
