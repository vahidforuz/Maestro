import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_data_source.dart';
import '../services/messaging_service.dart';
import '../services/messaging_inbox.dart';
import '../services/teacher_auth.dart';
import '../theme/maestro_theme.dart';
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
      this.onSwitchStudent});

  final MaestroDataSource api;
  final TeacherAuth auth;
  final SupabaseClient? client;
  final VoidCallback? onSwitchStudent;

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
    super.dispose();
  }

  void _clearTeacher() {
    _inbox?.dispose();
    _inbox = null;
    setState(() {
      _teacher = null;
      _selectedStudent = null;
      _section = AppSection.dashboard;
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

    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = _selectedStudent == null ? _sectionBody() : _studentProfile();

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              section: _section,
              onSelect: _selectSection,
              inbox: _inbox,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: AppSection.values.indexOf(_section),
        onDestinationSelected: (index) =>
            _selectSection(AppSection.values[index]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: _MessageBadge(
                inbox: _inbox, child: const Icon(Icons.chat_bubble_outline)),
            selectedIcon: _MessageBadge(
                inbox: _inbox, child: const Icon(Icons.chat_bubble)),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _sectionBody() {
    return switch (_section) {
      AppSection.dashboard => DashboardScreen(
          api: widget.api,
          teacher: _teacher!,
          onOpenStudents: () => _selectSection(AppSection.students),
          onOpenStudent: _openStudent,
          onOpenCalendar: () => _selectSection(AppSection.calendar),
          onAddStudent: _showAddStudentDialog,
        ),
      AppSection.students => StudentsScreen(
          api: widget.api,
          teacher: _teacher!,
          onOpenStudent: _openStudent,
        ),
      AppSection.calendar => CalendarScreen(
          api: widget.api,
          teacher: _teacher!,
          onOpenStudent: _openStudent,
          onOpenLesson: _openLesson,
          onTeacherChanged: (teacher) => setState(() => _teacher = teacher),
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
          onTeacherChanged: (teacher) => setState(() => _teacher = teacher),
          onSignOut: _signOut,
          onSwitchStudent: widget.onSwitchStudent,
        ),
    };
  }

  Widget _studentProfile() {
    return StudentProfileScreen(
      api: widget.api,
      studentId: _selectedStudent!.id,
      initialCourseId: _selectedCourseId,
      onBack: () => setState(() => _selectedStudent = null),
    );
  }

  void _selectSection(AppSection section) {
    setState(() {
      _section = section;
      _selectedStudent = null;
      _selectedCourseId = null;
    });
  }

  void _openStudent(Student student) {
    setState(() {
      _section = AppSection.students;
      _selectedStudent = student;
      _selectedCourseId = null;
    });
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
    );
    if (created != null) {
      _openStudent(created);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.inbox,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSelect;
  final MessagingInbox? inbox;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: MaestroColors.sidebar,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/maestro-icon.png',
                width: 36,
                height: 36,
              ),
              const SizedBox(width: 10),
              const Text(
                'Maestro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 54, top: 2, bottom: 16),
            child: Text(
              'Music teaching studio',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
          ),
          for (final item in AppSection.values)
            _SidebarItem(
              label: item.label,
              selected: item == section,
              onTap: () => onSelect(item),
              inbox: item == AppSection.messages ? inbox : null,
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.inbox,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MessagingInbox? inbox;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(44),
          backgroundColor:
              selected ? MaestroColors.primary : Colors.transparent,
          foregroundColor: selected ? Colors.white : const Color(0xFFD1D5DB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Row(children: [
            Expanded(
                child:
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (inbox != null) _UnreadPill(inbox: inbox!),
          ]),
        ),
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.inbox});
  final MessagingInbox inbox;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: inbox,
      builder: (_, __) {
        final count = inbox.unreadCount;
        if (count == 0) return const SizedBox.shrink();
        return Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10)),
            child: Text(count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)));
      });
}

class _MessageBadge extends StatelessWidget {
  const _MessageBadge({required this.inbox, required this.child});
  final MessagingInbox? inbox;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = inbox;
    if (value == null) return child;
    return AnimatedBuilder(
        animation: value,
        builder: (_, __) => Badge(
            isLabelVisible: value.unreadCount > 0,
            label:
                Text(value.unreadCount > 99 ? '99+' : '${value.unreadCount}'),
            child: child));
  }
}
