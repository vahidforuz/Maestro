import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_data_source.dart';
import '../services/messaging_service.dart';
import '../services/messaging_inbox.dart';
import '../services/teacher_auth.dart';
import '../services/student_portal_service.dart';
import '../theme/maestro_theme.dart';
import '../widgets/maestro_shell.dart';
import 'app_section.dart';
import 'calendar_screen.dart';
import 'messages_screen.dart';
import 'dashboard_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';
import 'student_profile_screen.dart';
import 'students_screen.dart';
import 'teacher_gate_screen.dart';

class MaestroApp extends StatefulWidget {
  const MaestroApp(
      {super.key,
      required this.api,
      required this.auth,
      this.client,
      this.onSwitchStudent,
      this.onSwitchParent});

  final MaestroDataSource api;
  final TeacherAuth auth;
  final SupabaseClient? client;
  final VoidCallback? onSwitchStudent;
  final VoidCallback? onSwitchParent;

  @override
  State<MaestroApp> createState() => _MaestroAppState();
}

class _MaestroAppState extends State<MaestroApp> {
  AppSection _section = AppSection.dashboard;
  Student? _selectedStudent;
  int? _selectedCourseId;
  Teacher? _teacher;
  StreamSubscription<bool>? _authSubscription;
  MessagingInbox? _inbox;
  String? _activeShortcut;
  final ValueNotifier<int> _emptyInbox = ValueNotifier<int>(0);
  final Map<AppSection, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.auth.sessionChanges.listen((signedIn) {
      if (!signedIn && mounted) _clearTeacher();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _inbox?.dispose();
    _emptyInbox.dispose();
    super.dispose();
  }

  void _clearTeacher() {
    _inbox?.dispose();
    _inbox = null;
    _pages.clear();
    setState(() {
      _teacher = null;
      _selectedStudent = null;
      _section = AppSection.dashboard;
      _activeShortcut = null;
    });
  }

  void _signedIn(Teacher teacher) {
    _inbox?.dispose();
    if (widget.client != null) {
      _inbox = MessagingInbox(MessagingService(widget.client!))..start();
    }
    setState(() => _teacher = teacher);
  }

  Future<void> _signOut() async {
    try {
      await MessagingService.clearDownloadedFiles();
      await widget.auth.signOut();
      if (mounted) _clearTeacher();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign out: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_teacher == null) {
      return Scaffold(
        body: TeacherGateScreen(
          api: widget.api,
          auth: widget.auth,
          onSignedIn: _signedIn,
        ),
      );
    }

    final body =
        _selectedStudent == null ? _cachedSections() : _studentProfile();
    return AnimatedBuilder(
      animation: _inbox ?? _emptyInbox,
      builder: (context, _) => MaestroShell(
        title: _section.label,
        userName: _teacher!.displayName,
        body: body,
        selectedIndex: switch (_section) {
          AppSection.students => 1,
          AppSection.calendar => 2,
          AppSection.messages => 3,
          AppSection.settings => 4,
          _ => 0,
        },
        shortcuts: [
          MaestroShortcut(
              'Payments',
              Icons.payments_outlined,
              MaestroAccents.green,
              () => _openShortcut('payments', AppSection.payments),
              selected: _section == AppSection.payments),
          MaestroShortcut('Availability', Icons.event_available_outlined,
              MaestroAccents.orange, _openAvailability,
              selected: _section == AppSection.calendar &&
                  _activeShortcut == 'availability'),
          MaestroShortcut(
              'Pieces / Projects',
              Icons.music_note_outlined,
              MaestroAccents.violet,
              () => _openShortcut('pieces', AppSection.students),
              selected: _section == AppSection.students &&
                  _activeShortcut == 'pieces'),
        ],
        unreadCount: _inbox?.unreadCount ?? 0,
        onProfile: () => _selectSection(AppSection.settings),
        onSettings: () => _selectSection(AppSection.settings),
        onSignOut: _signOut,
        destinations: [
          MaestroDestination('Home', Icons.home_outlined,
              () => _selectSection(AppSection.dashboard)),
          MaestroDestination('Students', Icons.people_outline,
              () => _selectSection(AppSection.students)),
          MaestroDestination('Calendar', Icons.calendar_month_outlined,
              () => _selectSection(AppSection.calendar)),
          MaestroDestination('Messages', Icons.chat_bubble_outline,
              () => _selectSection(AppSection.messages),
              badge: _inbox?.unreadCount ?? 0),
        ],
      ),
    );
  }

  Widget _cachedSections() {
    _pages.putIfAbsent(_section, _buildSectionBody);
    return IndexedStack(
      index: AppSection.values.indexOf(_section),
      children: [
        for (final section in AppSection.values)
          _pages[section] ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildSectionBody() {
    return switch (_section) {
      AppSection.dashboard => DashboardScreen(
          api: widget.api,
          teacher: _teacher!,
          onOpenStudents: () => _selectSection(AppSection.students),
          onOpenStudent: _openStudent,
          onOpenCalendar: () => _selectSection(AppSection.calendar),
          onAddStudent: _showAddStudentDialog,
          onOpenPayments: () => _selectSection(AppSection.payments),
          onOpenMessages: () => _selectSection(AppSection.messages),
          inbox: _inbox,
        ),
      AppSection.students => StudentsScreen(
          api: widget.api,
          teacher: _teacher!,
          onInviteStudent: widget.client == null
              ? null
              : (studentId, email) async {
                  await StudentPortalService(widget.client!)
                      .invite(studentId, email);
                },
          onOpenStudent: _openStudent,
          onMessageStudent: widget.client == null
              ? null
              : (student, studentId) =>
                  unawaited(_openStudentMessage(student, studentId)),
          loadMessageStudentIds:
              widget.client == null ? null : _loadMessageStudentIds,
          inbox: _inbox,
        ),
      AppSection.calendar => CalendarScreen(
          api: widget.api,
          teacher: _teacher!,
          initialAvailability: _activeShortcut == 'availability',
          onOpenStudent: _openStudent,
          onOpenLesson: _openLesson,
          onTeacherChanged: _teacherChanged,
        ),
      AppSection.messages => widget.client == null
          ? const Center(child: Text('Messaging needs a Supabase connection.'))
          : MessagesScreen(client: widget.client!, inbox: _inbox),
      AppSection.payments => PaymentsScreen(
          api: widget.api,
          teacher: _teacher!,
        ),
      AppSection.settings => SettingsScreen(
          api: widget.api,
          teacher: _teacher!,
          onTeacherChanged: _teacherChanged,
          onSignOut: _signOut,
          onSwitchStudent: widget.onSwitchStudent,
          onSwitchParent: widget.onSwitchParent,
        ),
    };
  }

  Widget _studentProfile() {
    return StudentProfileScreen(
      key: ValueKey(_selectedStudent!.id),
      api: widget.api,
      studentId: _selectedStudent!.id,
      initialCourseId: _selectedCourseId,
      onBack: () => setState(() => _selectedStudent = null),
    );
  }

  void _selectSection(AppSection section) {
    setState(() {
      if (_section == AppSection.calendar &&
          _activeShortcut == 'availability') {
        _pages.remove(AppSection.calendar);
      }
      _section = section;
      _activeShortcut = null;
      _selectedStudent = null;
      _selectedCourseId = null;
    });
  }

  void _openShortcut(String shortcut, AppSection section) => setState(() {
        if (_section == AppSection.calendar &&
            _activeShortcut == 'availability') {
          _pages.remove(AppSection.calendar);
        }
        _section = section;
        _activeShortcut = shortcut;
        _selectedStudent = null;
        _selectedCourseId = null;
      });

  void _openAvailability() => setState(() {
        _pages.remove(AppSection.calendar);
        _section = AppSection.calendar;
        _activeShortcut = 'availability';
        _selectedStudent = null;
        _selectedCourseId = null;
      });

  void _teacherChanged(Teacher teacher) => setState(() {
        _teacher = teacher;
        _pages.clear();
      });

  void _openStudent(Student student) {
    setState(() {
      _section = AppSection.students;
      _selectedStudent = student;
      _selectedCourseId = null;
    });
  }

  Future<Map<int, String>> _loadMessageStudentIds() async {
    final client = widget.client!;
    final ids = <int, String>{};
    const pageSize = 500;
    for (var offset = 0;; offset += pageSize) {
      final rows = await client
          .from('students')
          .select('id,app_id')
          .order('app_id')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        ids[(row['app_id'] as num).toInt()] = row['id'] as String;
      }
      if (rows.length < pageSize) break;
    }
    return ids;
  }

  Future<void> _openStudentMessage(Student student, String? studentId) async {
    final client = widget.client;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final teacher = await client
          .from('teachers')
          .select('id')
          .eq('user_id', userId)
          .single();
      final resolvedStudentId = studentId ??
          (await client
              .from('students')
              .select('id')
              .eq('app_id', student.id)
              .single())['id'] as String;
      final service = MessagingService(client);
      final teacherId = teacher['id'] as String;
      final conversationId = await service.open(teacherId, resolvedStudentId);
      if (!mounted || client.auth.currentUser?.id != userId) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatRoom(
                service: service,
                teacherId: teacherId,
                studentId: resolvedStudentId,
                name: student.displayName,
                instrument: student.instrument,
                conversationId: conversationId,
                onRead: _inbox?.scheduleRefresh,
              )));
      if (mounted) unawaited(_inbox?.refresh());
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException && error.code == '42501'
          ? 'Messaging is not available for this student yet.'
          : 'Could not open chat: $error';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openLesson(Student student, int courseId) {
    setState(() {
      _section = AppSection.students;
      _selectedStudent = student;
      _selectedCourseId = courseId;
    });
  }

  Future<void> _showAddStudentDialog() async {
    final teacher = _teacher;
    if (teacher == null) return;
    final created = await showAddStudentDialog(
      context,
      api: widget.api,
      teacher: teacher,
      onInviteStudent: widget.client == null
          ? null
          : (studentId, email) async {
              await StudentPortalService(widget.client!)
                  .invite(studentId, email);
            },
    );
    if (created != null) {
      if (!mounted) return;
      _pages.remove(AppSection.dashboard);
      _pages.remove(AppSection.students);
      _selectSection(AppSection.students);
    }
  }
}
