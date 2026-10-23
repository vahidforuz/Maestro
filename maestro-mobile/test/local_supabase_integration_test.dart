import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/core/config/supabase_environment.dart';
import 'package:maestro_mobile/models/time_block.dart';
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
    expect(ada.$1, containsAll({11, 12, 15}));
    expect(ben.$1, containsAll({13, 14, 15}));
    expect(ada.$2, contains(201));
    expect(ben.$2, contains(202));
    expect(ada.$2.intersection(ben.$2), isEmpty);
  });

  test('scheduled review survives a new Supabase client session',
      skip: !local ? 'Requires the local Supabase public defines' : null,
      () async {
    Future<(String, int?)> readReview() async {
      final client = SupabaseClient(
          SupabaseEnvironment.url, SupabaseEnvironment.publishableKey);
      try {
        await client.auth.signInWithPassword(
            email: 'ada.teacher@maestro.example', password: 'LocalMaestro123!');
        final student =
            await SupabaseMaestroDataSource(client).fetchStudent(11);
        final note = student.courses
            .expand((course) => course.notes)
            .singleWhere((note) => note.id == 301);
        return (note.comment, note.targetCourseId);
      } finally {
        await client.dispose();
      }
    }

    expect(await readReview(), ('Practice slowly', 1002));
    expect(await readReview(), ('Practice slowly', 1002));
  });

  test('blocked time survives a new Supabase client session',
      skip: !local ? 'Requires the local Supabase public defines' : null,
      () async {
    const title = 'Persistence test block';
    String? id;
    Future<SupabaseClient> signedIn() async {
      final client = SupabaseClient(
          SupabaseEnvironment.url, SupabaseEnvironment.publishableKey);
      await client.auth.signInWithPassword(
          email: 'ada.teacher@maestro.example', password: 'LocalMaestro123!');
      return client;
    }

    try {
      final first = await signedIn();
      try {
        final api = SupabaseMaestroDataSource(first);
        await api.saveTimeBlock(TimeBlock(
          id: '',
          title: title,
          category: BlockCategory.personal,
          start: DateTime.utc(2026, 10, 28, 14),
          end: DateTime.utc(2026, 10, 28, 16),
          allDay: false,
          repeat: BlockRepeat.daily,
          notes: 'Private',
        ));
        id = (await api.fetchTimeBlocks(
                DateTime.utc(2026, 10, 26), DateTime.utc(2026, 11, 1)))
            .singleWhere((block) => block.title == title)
            .id;
      } finally {
        await first.dispose();
      }
      final second = await signedIn();
      try {
        final blocks = await SupabaseMaestroDataSource(second).fetchTimeBlocks(
            DateTime.utc(2026, 11, 2), DateTime.utc(2026, 11, 8));
        final restored = blocks.singleWhere((block) => block.id == id);
        expect(restored.notes, 'Private');
        expect(restored.start.hour, 14);
        expect(
            restored.occurrences(
                DateTime.utc(2026, 11, 2), DateTime.utc(2026, 11, 8)),
            hasLength(7));
      } finally {
        await second.dispose();
      }
    } finally {
      if (id != null) {
        final cleanup = await signedIn();
        try {
          await SupabaseMaestroDataSource(cleanup).deleteTimeBlock(id);
        } finally {
          await cleanup.dispose();
        }
      }
    }
  });
}
