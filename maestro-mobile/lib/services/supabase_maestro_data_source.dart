import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/calendar_availability.dart';
import '../models/time_block.dart';
import 'calendar_availability_data_source.dart';
import 'maestro_data_source.dart';

/// The production data source. Authorization lives in PostgreSQL RLS/RPCs.
class SupabaseMaestroDataSource
    implements MaestroDataSource, CalendarAvailabilityDataSource {
  SupabaseMaestroDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TimeBlock>> fetchTimeBlocks(
      DateTime from, DateTime through) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    // A block may start before the window and still cover it (vacations).
    final rows = await _client
        .from('teacher_time_blocks')
        .select(
            'id,title,category,start_at,end_at,all_day,repeat,weekdays,repeat_until,notes,teacher_time_block_exceptions(occurrence_date,cancelled,start_at,end_at,title,category,notes)')
        .eq('teacher_id', teacherId)
        .lte('start_at', '${_sqlDate(through)}T23:59:59')
        .or('repeat.neq.never,end_at.gte.${_sqlDate(from)}T00:00:00');
    return [
      for (final row in rows)
        TimeBlock(
          id: row['id'] as String,
          title: row['title'] as String,
          category: BlockCategory.values.byName(row['category'] as String),
          start: _wallDate(row['start_at'] as String),
          end: _wallDate(row['end_at'] as String),
          allDay: row['all_day'] as bool,
          repeat: BlockRepeat.values.byName(row['repeat'] as String),
          weekdays: [
            for (final day in (row['weekdays'] as List<dynamic>? ?? []))
              day as int
          ],
          repeatUntil: row['repeat_until'] == null
              ? null
              : _wallDate(row['repeat_until'] as String),
          notes: row['notes'] as String?,
          exceptions: [
            for (final item
                in (row['teacher_time_block_exceptions'] as List<dynamic>? ??
                    []))
              TimeBlockException(
                date: _wallDate(item['occurrence_date'] as String),
                cancelled: item['cancelled'] as bool,
                start: item['start_at'] == null
                    ? null
                    : _wallDate(item['start_at'] as String),
                end: item['end_at'] == null
                    ? null
                    : _wallDate(item['end_at'] as String),
                title: item['title'] as String?,
                category: item['category'] == null
                    ? null
                    : BlockCategory.values.byName(item['category'] as String),
                notes: item['notes'] as String?,
              )
          ],
        )
    ];
  }

  @override
  Future<void> saveTimeBlock(TimeBlock block) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    final values = <String, dynamic>{
      'teacher_id': teacherId,
      'title': block.title,
      'category': block.category.name,
      'start_at': _localTimestamp(block.start),
      'end_at': _localTimestamp(block.end),
      'all_day': block.allDay,
      'repeat': block.repeat.name,
      'weekdays': block.weekdays,
      'repeat_until':
          block.repeatUntil == null ? null : _sqlDate(block.repeatUntil!),
      'notes': block.notes,
    };
    if (block.id.isEmpty) {
      await _client.from('teacher_time_blocks').insert(values);
    } else {
      await _client
          .from('teacher_time_blocks')
          .update(values)
          .eq('id', block.id)
          .eq('teacher_id', teacherId);
    }
  }

  @override
  Future<void> deleteTimeBlock(String id) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    await _client
        .from('teacher_time_blocks')
        .delete()
        .eq('id', id)
        .eq('teacher_id', teacherId);
  }

  @override
  Future<void> changeTimeBlockOccurrence(
      String blockId, DateTime occurrenceDate,
      {bool cancelled = false,
      DateTime? start,
      DateTime? end,
      String? title,
      BlockCategory? category,
      String? notes}) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    await _client.from('teacher_time_block_exceptions').upsert({
      'teacher_id': teacherId,
      'block_id': blockId,
      'occurrence_date': _sqlDate(occurrenceDate),
      'cancelled': cancelled,
      'start_at': start == null ? null : _localTimestamp(start),
      'end_at': end == null ? null : _localTimestamp(end),
      'title': title,
      'category': category?.name,
      'notes': notes,
    }, onConflict: 'block_id,occurrence_date');
  }

  static String _localTimestamp(DateTime date) =>
      '${_sqlDate(date)}T${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:00';

  static DateTime _wallDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
        parsed.minute, parsed.second);
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to continue.');
    return id;
  }

  Future<Map<String, dynamic>> _myTeacherRow() async {
    final row = await _client
        .from('teachers')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Create your teacher profile to continue.');
    }
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<List<AvailabilityPeriod>> fetchAvailability(
      DateTime weekStart, DateTime weekEnd) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    final from = _sqlDate(weekStart);
    final through = _sqlDate(weekEnd);
    final rules = await _client
        .from('teacher_availability_rules')
        .select(
            'id,weekday,start_minute,end_minute,kind,effective_from,effective_until')
        .eq('teacher_id', teacherId)
        .lte('effective_from', through)
        .or('effective_until.is.null,effective_until.gte.$from');
    final exceptions = await _client
        .from('teacher_availability_exceptions')
        .select('id,on_date,start_minute,end_minute,kind')
        .eq('teacher_id', teacherId)
        .gte('on_date', from)
        .lte('on_date', through);
    return [
      for (final row in rules)
        AvailabilityPeriod(
          id: row['id'] as String,
          weekday: row['weekday'] as int,
          startMinute: row['start_minute'] as int,
          endMinute: row['end_minute'] as int,
          available: row['kind'] == 'available',
          effectiveFrom: DateTime.parse(row['effective_from'] as String),
          effectiveUntil: row['effective_until'] == null
              ? null
              : DateTime.parse(row['effective_until'] as String),
        ),
      for (final row in exceptions)
        AvailabilityPeriod(
          id: row['id'] as String,
          date: DateTime.parse(row['on_date'] as String),
          startMinute: row['start_minute'] as int,
          endMinute: row['end_minute'] as int,
          available: row['kind'] == 'available',
        ),
    ];
  }

  @override
  Future<void> saveAvailability({
    String? id,
    required bool recurring,
    required DateTime date,
    required int startMinute,
    required int endMinute,
    required bool available,
    DateTime? effectiveUntil,
  }) async {
    if (startMinute < 0 || endMinute > 1440 || startMinute >= endMinute) {
      throw ArgumentError('Start time must be before end time.');
    }
    final teacherId = (await _myTeacherRow())['id'] as String;
    final table = recurring
        ? 'teacher_availability_rules'
        : 'teacher_availability_exceptions';
    final values = <String, dynamic>{
      'teacher_id': teacherId,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'kind': available ? 'available' : 'unavailable',
      if (recurring) ...{
        'weekday': date.weekday,
        'effective_from': _sqlDate(date),
        'effective_until':
            effectiveUntil == null ? null : _sqlDate(effectiveUntil),
      } else
        'on_date': _sqlDate(date),
    };
    if (id == null) {
      await _client.from(table).insert(values);
    } else {
      await _client
          .from(table)
          .update(values)
          .eq('id', id)
          .eq('teacher_id', teacherId);
    }
  }

  @override
  Future<void> deleteAvailability(String id, {required bool recurring}) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    final table = recurring
        ? 'teacher_availability_rules'
        : 'teacher_availability_exceptions';
    await _client.from(table).delete().eq('id', id).eq('teacher_id', teacherId);
  }

  @override
  Future<void> changeRecurringAvailability({
    required String id,
    required DateTime fromDate,
    required int startMinute,
    required int endMinute,
    required bool available,
    required bool delete,
  }) async {
    await _client.rpc('maestro_change_availability_rule', params: {
      'p_rule_id': id,
      'p_from_date': _sqlDate(fromDate),
      'p_start_minute': startMinute,
      'p_end_minute': endMinute,
      'p_kind': available ? 'available' : 'unavailable',
      'p_delete': delete,
    });
  }

  @override
  Future<void> copyAvailabilityDay(
      DateTime sourceDate, List<int> targetWeekdays) async {
    await _client.rpc('maestro_copy_availability_day', params: {
      'p_source_date': _sqlDate(sourceDate),
      'p_target_weekdays': targetWeekdays,
    });
  }

  @override
  Future<List<AvailabilityShareLink>> fetchAvailabilityShareLinks() async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    final rows = await _client
        .from('availability_share_links')
        .select('id,created_at,expires_at,range_from,range_until,revoked_at')
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        AvailabilityShareLink(
          id: row['id'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          expiresAt: row['expires_at'] == null
              ? null
              : DateTime.parse(row['expires_at'] as String),
          rangeFrom: row['range_from'] == null
              ? null
              : DateTime.parse(row['range_from'] as String),
          rangeUntil: row['range_until'] == null
              ? null
              : DateTime.parse(row['range_until'] as String),
          revokedAt: row['revoked_at'] == null
              ? null
              : DateTime.parse(row['revoked_at'] as String),
        )
    ];
  }

  @override
  Future<CreatedAvailabilityShareLink> createAvailabilityShareLink(
      {DateTime? expiresAt, DateTime? rangeFrom, DateTime? rangeUntil}) async {
    final row = Map<String, dynamic>.from(
        await _client.rpc('maestro_create_availability_link', params: {
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      'p_range_from': rangeFrom == null ? null : _sqlDate(rangeFrom),
      'p_range_until': rangeUntil == null ? null : _sqlDate(rangeUntil),
    }) as Map);
    return CreatedAvailabilityShareLink(
        row['id'] as String, row['token'] as String);
  }

  @override
  Future<void> revokeAvailabilityShareLink(String id) async {
    final teacherId = (await _myTeacherRow())['id'] as String;
    await _client
        .from('availability_share_links')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('teacher_id', teacherId);
  }

  @override
  Future<List<CalendarUtcRange>> convertCalendarRanges(
      List<CalendarLocalRange> ranges) async {
    final rows = await _client.rpc('maestro_convert_calendar_ranges', params: {
      'p_ranges': [
        for (final range in ranges)
          {
            'date': _sqlDate(range.date),
            'startMinute': range.startMinute,
            'endMinute': range.endMinute,
          }
      ],
    }) as List<dynamic>;
    return [
      for (final row in rows)
        CalendarUtcRange(
          DateTime.parse(row['startAt'] as String).toUtc(),
          DateTime.parse(row['endAt'] as String).toUtc(),
        )
    ];
  }

  static String _sqlDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<List<Teacher>> fetchTeachers() async {
    if (_client.auth.currentUser == null) return [];
    final rows = await _client.from('teachers').select().eq('user_id', _userId);
    return rows.map((row) => _teacher(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<Teacher> fetchTeacher(int id) async {
    final row = await _myTeacherRow();
    if (row['app_id'] != id) throw StateError('Teacher profile not found.');
    return _teacher(row);
  }

  @override
  Future<Teacher> createTeacher(Map<String, dynamic> request) async {
    final row = await _client.rpc('register_teacher_with_contact', params: {
      'p_first_name': request['firstName'] ?? '',
      'p_last_name': request['lastName'] ?? '',
      'p_telephone': request['telephone'],
      'p_contact_email': request['email'],
    });
    return Teacher.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Teacher> updateTeacher(int id, Map<String, dynamic> request) async {
    final current = await _myTeacherRow();
    if (current['app_id'] != id) throw StateError('Teacher profile not found.');
    final changes = <String, dynamic>{
      'name': request['name'],
      'first_name': request['firstName'],
      'last_name': request['lastName'],
      'studio_name': request['studioName'],
      'email': request['email'],
      'telephone': request['telephone'],
      'address': request['address'],
      'city': request['city'],
      'postal_code': request['postalCode'],
      'main_instrument': request['mainInstrument'],
      'other_instruments': request['otherInstruments'],
      'default_lesson_duration': request['defaultLessonDuration'],
      'timezone': request['timezone'],
      'default_lesson_price': request['defaultLessonPrice'],
      'currency': request['currency'],
      'profile_image_path': request['profileImagePath'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((_, value) => value == null);
    final row = await _client
        .from('teachers')
        .update(changes)
        .eq('app_id', id)
        .eq('user_id', _userId)
        .select()
        .single();
    return _teacher(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Student>> fetchStudents() async {
    await _myTeacherRow();
    final rows =
        await _client.from('students').select('id,app_id').order('app_id');
    final students = <Student>[];
    for (final row in rows) {
      students.add(await fetchStudent(row['app_id'] as int));
    }
    return students;
  }

  @override
  Future<Student> fetchStudent(int id) async {
    final teacher = await _myTeacherRow();
    final raw = await _client
        .from('students')
        .select(
          'id,app_id,first_name,family_name,name,email,phone,birthday,status,'
          'instrument,level,course_day,course_hour,present,first_course_status,'
          'next_week_assignment,this_week_comment',
        )
        .eq('app_id', id)
        .maybeSingle();
    if (raw == null) throw StateError('Student not found or access denied.');
    final row = Map<String, dynamic>.from(raw);
    final studentUuid = row['id'] as String;
    final finances = Map<String, dynamic>.from(await _client.rpc(
      'get_student_finances',
      params: {'p_student_id': studentUuid},
    ) as Map);
    final projectRows = await _client
        .from('projects')
        .select('id,app_id,name,sort_order')
        .eq('student_id', studentUuid)
        .order('sort_order')
        .order('app_id');
    final lessonRows = await _client
        .from('lessons')
        .select(
          'id,app_id,project_id,title,day,lesson_date,hour,duration_minutes,price,status,'
          'assignment,comment,homework_next_lesson,sort_order',
        )
        .eq('student_id', studentUuid)
        .order('sort_order')
        .order('app_id');
    final pieceRows = await _client
        .from('pieces')
        .select('project_id,title,sort_order,app_id')
        .eq('student_id', studentUuid)
        .order('sort_order')
        .order('app_id');
    final noteRows = await _client
        .from('lesson_notes')
        .select(
          'id,app_id,lesson_id,piece,comment,created_date,review_weeks,'
          'review_date,review_status,source_lesson_id,accepted_lesson_id,'
          'target_lesson_id,reviewed_date,review_history,sort_order',
        )
        .eq('student_id', studentUuid)
        .order('sort_order')
        .order('app_id');
    final lessonIds = <String, int>{
      for (final lesson in lessonRows)
        lesson['id'] as String: lesson['app_id'] as int,
    };
    final courses = <Map<String, dynamic>>[];
    final projects = <Map<String, dynamic>>[];
    for (final project in projectRows) {
      final uuid = project['id'] as String;
      final projectFinances = Map<String, dynamic>.from(await _client.rpc(
        'get_project_finances',
        params: {'p_project_id': uuid},
      ) as Map);
      final projectCourses = <Map<String, dynamic>>[];
      for (final lesson
          in lessonRows.where((lesson) => lesson['project_id'] == uuid)) {
        final notes = noteRows
            .where((note) => note['lesson_id'] == lesson['id'])
            .map((note) => <String, dynamic>{
                  'id': note['app_id'],
                  'piece': note['piece'],
                  'comment': note['comment'],
                  'createdDate': note['created_date'],
                  'reviewWeeks': note['review_weeks'],
                  'reviewDate': note['review_date'],
                  'reviewStatus': note['review_status'],
                  'sourceCourseId':
                      lessonIds[note['source_lesson_id']] ?? lesson['app_id'],
                  'acceptedCourseId': lessonIds[note['accepted_lesson_id']],
                  'targetCourseId': lessonIds[note['target_lesson_id']],
                  'reviewedDate': note['reviewed_date'],
                  'reviewHistory': note['review_history'],
                })
            .toList();
        final course = <String, dynamic>{
          'id': lesson['app_id'],
          'title': lesson['title'],
          'day': lesson['day'],
          'date': lesson['lesson_date'],
          'hour': _time(lesson['hour']),
          'durationMinutes': lesson['duration_minutes'],
          'price': _number(lesson['price']),
          'status': lesson['status'],
          'assignment': lesson['assignment'],
          'comment': lesson['comment'],
          'homeworkNextLesson': lesson['homework_next_lesson'],
          'notes': notes,
        };
        projectCourses.add(course);
        courses.add(course);
      }
      projects.add({
        'id': project['app_id'],
        'name': project['name'],
        'paidCourseCount': projectFinances['paidCourseCount'],
        'courses': projectCourses,
        'pieces': pieceRows
            .where((piece) => piece['project_id'] == uuid)
            .map((piece) => piece['title'] as String)
            .toList(),
      });
    }
    return Student.fromJson({
      'id': row['app_id'],
      'name': row['name'],
      'firstName': row['first_name'],
      'familyName': row['family_name'],
      'email': row['email'],
      'phone': row['phone'],
      'birthday': row['birthday'],
      'status': row['status'],
      'instrument': row['instrument'],
      'level': row['level'],
      'teacherId': teacher['app_id'],
      'courseDay': row['course_day'],
      'courseHour': _time(row['course_hour']),
      'coursePrice': _number(finances['coursePrice']),
      'paymentCreditBalance': _number(finances['paymentCreditBalance']),
      'present': row['present'],
      'firstCourseStatus': row['first_course_status'],
      'nextWeekAssignment': row['next_week_assignment'],
      'thisWeekComment': row['this_week_comment'],
      'courses': courses,
      'projects': projects,
    });
  }

  @override
  Future<Student> createStudent(Map<String, dynamic> request) async {
    final id = await _client
        .rpc('maestro_create_student', params: {'p_data': request});
    return fetchStudent((id as num).toInt());
  }

  @override
  Future<List<Payment>> fetchPayments() async {
    await _myTeacherRow();
    final rows = await _client
        .from('payments')
        .select(
          'app_id,student_id,amount,payment_date,method,note',
        )
        .order('payment_date', ascending: false);
    final students = await _client.from('students').select('id,app_id,name');
    final names = <String, Map<String, dynamic>>{
      for (final student in students)
        student['id'] as String: Map<String, dynamic>.from(student),
    };
    return rows
        .map((row) =>
            _payment(Map<String, dynamic>.from(row), names[row['student_id']]))
        .toList();
  }

  @override
  Future<List<Payment>> fetchStudentPayments(int studentId) async {
    final student = await _client
        .from('students')
        .select('id,app_id,name')
        .eq('app_id', studentId)
        .single();
    final rows = await _client
        .from('payments')
        .select(
          'app_id,student_id,amount,payment_date,method,note',
        )
        .eq('student_id', student['id'])
        .order('payment_date', ascending: false);
    return rows
        .map((row) => _payment(
            Map<String, dynamic>.from(row), Map<String, dynamic>.from(student)))
        .toList();
  }

  @override
  Future<Payment> createPayment(
      int studentId, Map<String, dynamic> request) async {
    final id = await _client.rpc('maestro_record_payment', params: {
      'p_student_app_id': studentId,
      'p_data': request,
      'p_request_key': _newUuid(),
    });
    final row = await _client
        .from('payments')
        .select(
          'app_id,student_id,amount,payment_date,method,note',
        )
        .eq('app_id', id)
        .single();
    final student = await _client
        .from('students')
        .select('id,app_id,name')
        .eq('id', row['student_id'])
        .single();
    return _payment(
        Map<String, dynamic>.from(row), Map<String, dynamic>.from(student));
  }

  Future<Student> _command(
    String operation,
    int studentId, {
    int? projectId,
    int? entityId,
    Map<String, dynamic> payload = const {},
  }) async {
    await _client.rpc('maestro_student_command', params: {
      'p_operation': operation,
      'p_student_app_id': studentId,
      'p_project_app_id': projectId,
      'p_entity_app_id': entityId,
      'p_payload': payload,
    });
    return fetchStudent(studentId);
  }

  @override
  Future<Student> addProject(int studentId, Map<String, dynamic> request) =>
      _command('add_project', studentId, payload: request);
  @override
  Future<Student> updateProject(
          int studentId, int projectId, Map<String, dynamic> request) =>
      _command('update_project', studentId,
          projectId: projectId, payload: request);
  @override
  Future<Student> deleteProject(int studentId, int projectId) =>
      _command('delete_project', studentId, projectId: projectId);
  @override
  Future<Student> addPiece(
          int studentId, int projectId, Map<String, dynamic> request) =>
      _command('add_piece', studentId, projectId: projectId, payload: request);
  @override
  Future<Student> updatePiece(int studentId, int projectId, int pieceIndex,
          Map<String, dynamic> request) =>
      _command('update_piece', studentId,
          projectId: projectId,
          payload: {...request, 'pieceIndex': pieceIndex});
  @override
  Future<Student> deletePiece(int studentId, int projectId, int pieceIndex) =>
      _command('delete_piece', studentId,
          projectId: projectId, payload: {'pieceIndex': pieceIndex});
  @override
  Future<Student> addCourse(int studentId, int projectId) =>
      _command('add_lesson', studentId, projectId: projectId);
  @override
  Future<Student> updateCourse(int studentId, int projectId, int courseId,
      Map<String, dynamic> request) async {
    await _client.rpc('maestro_update_lesson_with_duration', params: {
      'p_student_app_id': studentId,
      'p_project_app_id': projectId,
      'p_lesson_app_id': courseId,
      'p_payload': request,
    });
    return fetchStudent(studentId);
  }

  @override
  Future<Student> deleteCourse(int studentId, int projectId, int courseId) =>
      _command('delete_lesson', studentId,
          projectId: projectId, entityId: courseId);
  @override
  Future<Student> addNote(int studentId, int projectId, int courseId,
          Map<String, dynamic> request) =>
      _command('add_note', studentId,
          projectId: projectId, entityId: courseId, payload: request);
  @override
  Future<Student> updateNote(int studentId, int projectId, int courseId,
          int noteId, Map<String, dynamic> request) =>
      _command('update_note', studentId,
          projectId: projectId,
          entityId: courseId,
          payload: {...request, 'noteId': noteId});
  @override
  Future<Student> deleteNote(
          int studentId, int projectId, int courseId, int noteId) =>
      _command('delete_note', studentId,
          projectId: projectId,
          entityId: courseId,
          payload: {'noteId': noteId});

  @override
  Future<int> applyNotesToAllFutureWeeks(int studentId, int courseId) async {
    final count =
        await _client.rpc('maestro_apply_notes_to_future_lessons', params: {
      'p_student_app_id': studentId,
      'p_course_app_id': courseId,
    });
    return count as int;
  }

  @override
  Future<Student> markReviewReviewed(int studentId, int noteId, int courseId) =>
      _command('accept_review', studentId,
          entityId: noteId, payload: {'courseId': courseId});
  @override
  Future<Student> keepReviewForNextCourse(
          int studentId, int noteId, int courseId) =>
      _command('reschedule_review', studentId,
          entityId: noteId, payload: {'courseId': courseId});

  static Teacher _teacher(Map<String, dynamic> row) => Teacher.fromJson({
        'id': row['app_id'],
        'name': row['name'],
        'telephone': row['telephone'],
        'email': row['email'],
        'address': row['address'],
        'status': row['status'],
        'firstName': row['first_name'],
        'lastName': row['last_name'],
        'studioName': row['studio_name'],
        'city': row['city'],
        'postalCode': row['postal_code'],
        'mainInstrument': row['main_instrument'],
        'otherInstruments': row['other_instruments'],
        'defaultLessonDuration': row['default_lesson_duration'],
        'timezone': row['timezone'],
        'defaultLessonPrice': _number(row['default_lesson_price']),
        'currency': row['currency'],
        'profileImagePath': row['profile_image_path'],
      });

  static Payment _payment(
          Map<String, dynamic> row, Map<String, dynamic>? student) =>
      Payment.fromJson({
        'id': row['app_id'],
        'amount': _number(row['amount']),
        'paymentDate': row['payment_date'],
        'method': row['method'],
        'note': row['note'],
        'student': student == null
            ? null
            : {'id': student['app_id'], 'name': student['name']},
      });

  static double _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  static String? _time(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty
        ? null
        : text.substring(0, min(5, text.length));
  }

  static String _newUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }
}
