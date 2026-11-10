import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/student_portal_service.dart';
import '../services/messaging_inbox.dart';
import '../services/messaging_service.dart';
import '../theme/maestro_theme.dart';
import 'messages_screen.dart';
import '../widgets/maestro_card.dart';
import '../widgets/maestro_shell.dart';
import '../widgets/dashboard_layout.dart';

class StudentPortalScreen extends StatefulWidget {
  const StudentPortalScreen(
      {super.key,
      required this.client,
      required this.onSignOut,
      required this.onSwitchTeacher,
      this.onSwitchParent,
      this.service,
      this.canSwitchTeacher = false});

  final SupabaseClient client;
  final StudentPortalService? service;
  final VoidCallback onSignOut;
  final VoidCallback onSwitchTeacher;
  final VoidCallback? onSwitchParent;
  final bool canSwitchTeacher;

  @override
  State<StudentPortalScreen> createState() => _StudentPortalScreenState();
}

class _StudentPortalScreenState extends State<StudentPortalScreen>
    with WidgetsBindingObserver {
  late final StudentPortalService _service =
      widget.service ?? StudentPortalService(widget.client);
  late Future<List<Map<String, dynamic>>> _future = _service.loadPortals();
  String? _selectedTeacher;
  int _section = 0;
  final PageStorageBucket _pageStorage = PageStorageBucket();
  late final MessagingInbox _inbox =
      MessagingInbox(MessagingService(widget.client));
  static const _titles = [
    'Dashboard',
    'My Courses',
    'Lesson Notes',
    'My Reviews',
    'My Pieces',
    'Payments',
    'Messages',
    'My Profile'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.client.auth.currentUser != null) _inbox.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inbox.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() => setState(() => _future = _service.loadPortals());

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) =>
      (data[key] as List<dynamic>? ?? const [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse('$value');
  String _dateText(Object? value) {
    final date = _date(value);
    return date == null ? 'Date to be set' : DateFormat.yMMMd().format(date);
  }

  bool _allowed(Map<String, dynamic> data, String key) =>
      (data['permissions'] as Map)[key] == true;

  String _status(Object? value) => switch ('$value') {
        'PRESENT' => 'Completed',
        'CANCELED' => 'Cancelled',
        'ABSENT' => 'Absent',
        'MOVED' => 'Rescheduled',
        _ => 'Scheduled',
      };

  String _pieceStatus(Object? value) => switch ('$value') {
        'NOT_STARTED' => 'Not started',
        'PRACTICING' => 'Practicing',
        'READY' => 'Ready',
        'COMPLETE' => 'Complete',
        _ => 'In progress',
      };

  String _balanceText(Object? value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null) return 'Balance unavailable';
    if (amount > 0) return 'Amount due: ${amount.toStringAsFixed(2)}';
    if (amount < 0) return 'Credit: ${(-amount).toStringAsFixed(2)}';
    return 'Paid in full';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Could not load your portal: ${snapshot.error}'),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ])));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: SafeArea(child: DashboardSkeleton()));
        }
        final portals = snapshot.data!;
        if (portals.isEmpty) {
          return Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Student access is not active. Ask your teacher for an invitation.'),
            TextButton(onPressed: _refresh, child: const Text('Refresh')),
            TextButton(
                onPressed: widget.onSignOut, child: const Text('Sign out')),
          ])));
        }
        final portal = portals.firstWhere(
            (item) => item['teacherId'] == _selectedTeacher,
            orElse: () => portals.first);
        final body = _section == 6
            ? MessagesScreen(
                client: widget.client, teacher: false, inbox: _inbox)
            : _section == 0
                ? _content(portal)
                : RefreshIndicator(
                    onRefresh: () async {
                      _refresh();
                      await _future;
                    },
                    child: ListView(
                        key: PageStorageKey('student-section-$_section'),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    _section == 8
                                        ? 'Calendar'
                                        : _titles[_section],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall)),
                            IconButton(
                                onPressed: _refresh,
                                tooltip: 'Refresh',
                                icon: const Icon(Icons.refresh)),
                          ]),
                          if (portals.length > 1)
                            DropdownButton<String>(
                                value: portal['teacherId'] as String,
                                items: [
                                  for (final item in portals)
                                    DropdownMenuItem(
                                        value: item['teacherId'] as String,
                                        child:
                                            Text(item['teacherName'] as String))
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedTeacher = value)),
                          if (_section == 1 ||
                              _section == 2 ||
                              _section == 3 ||
                              _section == 8)
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              ChoiceChip(
                                  label: const Text('My Lessons'),
                                  selected: _section == 1,
                                  onSelected: (_) =>
                                      setState(() => _section = 1)),
                              if (_allowed(portal, 'viewNotes'))
                                ChoiceChip(
                                    label: const Text('Lesson Notes'),
                                    selected: _section == 2,
                                    onSelected: (_) =>
                                        setState(() => _section = 2)),
                              if (_allowed(portal, 'viewReviews'))
                                ChoiceChip(
                                    label: const Text('My Reviews'),
                                    selected: _section == 3,
                                    onSelected: (_) =>
                                        setState(() => _section = 3)),
                            ]),
                          const SizedBox(height: 14),
                          _content(portal),
                        ]));
        return AnimatedBuilder(
            animation: _inbox,
            builder: (context, _) => MaestroShell(
                  title: _section == 0
                      ? 'Maestro'
                      : _section == 8
                          ? 'Calendar'
                          : _titles[_section],
                  userName: '${portal['studentName']}',
                  body: PageStorage(bucket: _pageStorage, child: body),
                  selectedIndex: _section == 6
                      ? 3
                      : _section == 1 ||
                              _section == 2 ||
                              _section == 3 ||
                              _section == 4
                          ? 1
                          : _section == 8
                              ? 2
                              : _section == 7
                                  ? 4
                                  : 0,
                  shortcuts: [
                    if (_allowed(portal, 'viewPayments') ||
                        _allowed(portal, 'viewBalance'))
                      MaestroShortcut(
                          'Payments',
                          Icons.payments_outlined,
                          MaestroAccents.green,
                          () => setState(() => _section = 5),
                          selected: _section == 5),
                    if (_allowed(portal, 'viewPieces'))
                      MaestroShortcut(
                          'Pieces / Projects',
                          Icons.music_note_outlined,
                          MaestroAccents.violet,
                          () => setState(() => _section = 4),
                          selected: _section == 4),
                  ],
                  unreadCount: _inbox.unreadCount,
                  onProfile: () => setState(() => _section = 7),
                  onSettings: () => setState(() => _section = 7),
                  onSignOut: widget.onSignOut,
                  destinations: [
                    MaestroDestination('Home', Icons.home_outlined,
                        () => setState(() => _section = 0)),
                    MaestroDestination('Lessons', Icons.menu_book_outlined,
                        () => setState(() => _section = 1)),
                    MaestroDestination(
                        'Calendar',
                        Icons.calendar_month_outlined,
                        () => setState(() => _section = 8)),
                    MaestroDestination('Messages', Icons.chat_bubble_outline,
                        () => setState(() => _section = 6),
                        badge: _inbox.unreadCount),
                  ],
                ));
      });

  Widget _content(Map<String, dynamic> data) {
    final courses = _list(data, 'courses');
    final notes = _list(data, 'notes');
    final pieces = _list(data, 'pieces');
    final payments = _list(data, 'payments');
    final today = DateTime.now();
    final reviewNotes = notes.where((n) => n['reviewDate'] != null).toList()
      ..sort((a, b) => '${a['reviewDate']}'.compareTo('${b['reviewDate']}'));
    final sharedNotes =
        notes.where((n) => n['piece'] != null || n['comment'] != null).toList();
    final courseNames = {
      for (final course in courses) course['id']: course['title']
    };

    if (_section == 0) {
      final next = courses.where((course) {
        final date = _date(course['date']);
        return date != null &&
            !date.isBefore(DateTime(today.year, today.month, today.day)) &&
            course['status'] == 'NOTHING';
      }).toList()
        ..sort((a, b) => '${a['date']} ${a['hour'] ?? ''}'
            .compareTo('${b['date']} ${b['hour'] ?? ''}'));
      return DashboardLayout(
        greeting: 'Welcome, ${data['studentName']}',
        stats: [
          DashboardStat(
              'Upcoming Lessons',
              _allowed(data, 'viewCourses') ? '${next.length}' : '—',
              Icons.event_note_outlined,
              accent: MaestroAccents.violet),
          DashboardStat(
              'Homework',
              _allowed(data, 'viewCourses')
                  ? '${courses.where((c) => '${c['homework'] ?? ''}'.isNotEmpty).length}'
                  : '—',
              Icons.task_alt,
              accent: MaestroAccents.orange),
          DashboardStat(
              'Pieces in Progress',
              _allowed(data, 'viewPieces')
                  ? '${pieces.where((p) => p['status'] != 'COMPLETE').length}'
                  : '—',
              Icons.music_note_outlined,
              accent: MaestroAccents.cyan),
          DashboardStat(
              'Scheduled Reviews',
              _allowed(data, 'viewReviews')
                  ? '${reviewNotes.where((n) => _date(n['reviewDate'])?.isAfter(today) == true).length}'
                  : '—',
              Icons.rate_review_outlined,
              accent: MaestroAccents.violet),
        ],
        actions: [
          DashboardAction('My Lessons', Icons.menu_book_outlined,
              () => setState(() => _section = 1),
              accent: MaestroAccents.violet),
          DashboardAction(
              'Homework', Icons.task_alt, () => setState(() => _section = 1),
              accent: MaestroAccents.orange),
          DashboardAction(
              'My Pieces',
              Icons.music_note_outlined,
              _allowed(data, 'viewPieces')
                  ? () => setState(() => _section = 4)
                  : null,
              accent: MaestroAccents.cyan),
          const DashboardAction(
              'Practice Videos', Icons.video_library_outlined, null,
              accent: MaestroAccents.cyan),
          DashboardAction('Messages', Icons.chat_bubble_outline,
              () => setState(() => _section = 6),
              accent: MaestroAccents.pink),
          DashboardAction('Calendar', Icons.calendar_month_outlined,
              () => setState(() => _section = 8),
              accent: MaestroAccents.orange),
        ],
        sections: [
          _card(
              'Next Lesson',
              _allowed(data, 'viewCourses') && next.isNotEmpty
                  ? '${next.first['title']} · ${_dateText(next.first['date'])} ${next.first['hour'] ?? ''}'
                  : 'No upcoming lesson to show'),
          _card(
              "Teacher's Shared Notes",
              _allowed(data, 'viewNotes')
                  ? (sharedNotes.isEmpty
                      ? 'No shared notes yet'
                      : sharedNotes
                          .take(3)
                          .map((n) =>
                              '${n['piece'] ?? ''} ${n['comment'] ?? ''}')
                          .join('\n'))
                  : 'Not shared'),
          _card(
              'Homework',
              _allowed(data, 'viewCourses')
                  ? (courses
                          .where((c) => '${c['homework'] ?? ''}'.isNotEmpty)
                          .map((c) => '${c['homework']}')
                          .take(3)
                          .join('\n')
                          .isEmpty
                      ? 'No homework assigned.'
                      : courses
                          .where((c) => '${c['homework'] ?? ''}'.isNotEmpty)
                          .map((c) => '${c['homework']}')
                          .take(3)
                          .join('\n'))
                  : 'Not shared'),
          _card(
              'Practice Progress',
              _allowed(data, 'viewPieces')
                  ? (pieces.isEmpty
                      ? 'No pieces yet'
                      : pieces
                          .take(3)
                          .map((p) =>
                              '${p['title']} · ${_pieceStatus(p['status'])}')
                          .join('\n'))
                  : 'Not shared'),
          AnimatedBuilder(
            animation: _inbox,
            builder: (context, _) => _card(
              'Recent Messages',
              _inbox.conversations.isEmpty
                  ? '${_inbox.unreadCount} unread · No recent messages.'
                  : '${_inbox.unreadCount} unread\n${_inbox.conversations.take(3).map((m) => '${m['name']}: ${m['lastMessage'] ?? ''}').join('\n')}',
            ),
          ),
          if (_allowed(data, 'viewPayments') || _allowed(data, 'viewBalance'))
            _card('Payments',
                '${payments.length} recorded payments${data['balance'] == null ? '' : ' · ${_balanceText(data['balance'])}'}'),
        ],
      );
    }
    if (_section == 1 || _section == 8) {
      return _allowed(data, 'viewCourses')
          ? _items(courses, (course) {
              final number = courses.indexOf(course) + 1;
              final related = notes
                  .where((note) => note['courseId'] == course['id'])
                  .toList();
              return ListTile(
                title: Text('Course $number · ${course['title']}'),
                subtitle: Text(
                    '${_dateText(course['date'])} ${course['hour'] ?? ''} · '
                    '${course['durationMinutes'] ?? '—'} min · ${_status(course['status'])}'
                    '${course['homework'] == null || course['homework'] == '' ? '' : '\nHomework: ${course['homework']}'}'
                    '${related.where((n) => n['comment'] != null).isEmpty ? '' : '\nShared notes: ${related.where((n) => n['comment'] != null).map((n) => n['comment']).join('; ')}'}'
                    '${related.where((n) => n['reviewDate'] != null).isEmpty ? '' : '\nReviews: ${related.where((n) => n['reviewDate'] != null).map((n) => _dateText(n['reviewDate'])).join(', ')}'}'),
              );
            })
          : _card('My Courses', 'Your teacher has not enabled course access.');
    }
    if (_section == 2) {
      return _allowed(data, 'viewNotes')
          ? _items(
              sharedNotes,
              (note) => ListTile(
                  title: Text('${note['piece'] ?? 'Lesson note'}'),
                  subtitle: Text('${_dateText(note['createdDate'])} · '
                      '${courseNames[note['courseId']] ?? 'Course'}\n${note['comment'] ?? ''}')))
          : _card('Lesson Notes', 'Your teacher has not enabled notes.');
    }
    if (_section == 3) {
      return _allowed(data, 'viewReviews')
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final group in ['This week', 'Upcoming', 'Previous']) ...[
                Text(group, style: Theme.of(context).textTheme.titleMedium),
                _items(
                    reviewNotes.where((note) {
                      final date = _date(note['reviewDate'])!;
                      final weekStart =
                          DateTime(today.year, today.month, today.day)
                              .subtract(Duration(days: today.weekday - 1));
                      final nextWeek = weekStart.add(const Duration(days: 7));
                      return switch (group) {
                        'This week' =>
                          !date.isBefore(weekStart) && date.isBefore(nextWeek),
                        'Upcoming' => !date.isBefore(nextWeek),
                        _ => date.isBefore(weekStart),
                      };
                    }).toList(),
                    (note) => ListTile(
                          title: Text(
                              '${note['piece'] ?? 'Review'} · ${_dateText(note['reviewDate'])}'),
                          subtitle: Text(
                              'Course: ${courseNames[note['courseId']] ?? note['courseTitle'] ?? 'Lesson'}'
                              '${note['comment'] == null ? '' : '\n${note['comment']}'}'
                              '\nStatus: ${note['reviewStatus'] ?? 'Pending'}'),
                        )),
              ],
            ])
          : _card('My Reviews', 'Your teacher has not enabled reviews.');
    }
    if (_section == 4) {
      return _allowed(data, 'viewPieces')
          ? _items(
              pieces,
              (piece) => ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text('${piece['title']}'),
                  subtitle: Text(
                      '${piece['project']} · ${_pieceStatus(piece['status'])}'
                      '${piece['instructions'] == null || piece['instructions'] == '' ? '' : '\n${piece['instructions']}'}')))
          : _card('My Pieces', 'Your teacher has not enabled pieces.');
    }
    if (_section == 5) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_allowed(data, 'viewBalance'))
          _card(
              'Account balance',
              '${_balanceText(data['balance'])}'
                  '${data['courseCredits'] == null ? '' : ' · ${data['courseCredits']} course credits'}'),
        if (_allowed(data, 'viewPayments'))
          _items(
              payments,
              (payment) => ListTile(
                  title: Text('${payment['amount']}'),
                  subtitle: Text(
                      '${_dateText(payment['date'])} · ${payment['method'] ?? 'Payment'}'))),
        if (!_allowed(data, 'viewBalance') && !_allowed(data, 'viewPayments'))
          _card(
              'Payments', 'Your teacher has not enabled payment information.'),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
          'Account',
          '${widget.client.auth.currentUser?.email ?? ''}\n'
              'Student: ${data['studentName']}\nTeacher: ${data['teacherName']}'),
      OutlinedButton.icon(
          onPressed: _changeAccountEmail,
          icon: const Icon(Icons.alternate_email),
          label: const Text('Change account email')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: () async {
            try {
              final email = widget.client.auth.currentUser?.email;
              if (email == null) return;
              await widget.client.auth.resetPasswordForEmail(email);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password reset email sent.')));
              }
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Could not send reset email: $error')));
              }
            }
          },
          icon: const Icon(Icons.lock_outline),
          label: const Text('Reset password')),
      if (widget.canSwitchTeacher) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onSwitchTeacher,
          icon: const Icon(Icons.school_outlined),
          label: const Text('Teacher Portal'),
        ),
      ],
      if (widget.onSwitchParent != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onSwitchParent,
          icon: const Icon(Icons.family_restroom_outlined),
          label: const Text('Parent Portal'),
        ),
      ],
    ]);
  }

  Future<void> _changeAccountEmail() async {
    final controller = TextEditingController(
        text: widget.client.auth.currentUser?.email ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change account email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email address'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email == widget.client.auth.currentUser?.email) return;
    if (!RegExp(r'^[^ @]+@[^ @]+\.[^ @]+$').hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid email address.')));
      }
      return;
    }
    try {
      await widget.client.auth.updateUser(UserAttributes(email: email));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Check your email to confirm the change.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not change email: $error')));
      }
    }
  }

  Widget _card(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MaestroCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (body.startsWith('No ') || body == 'Not shared')
          DashboardEmptyState(body)
        else
          Text(body)
      ])));

  Widget _items(List<Map<String, dynamic>> items,
      Widget Function(Map<String, dynamic>) itemBuilder) {
    if (items.isEmpty) {
      return _card('Nothing to show yet', 'Check back after your next lesson.');
    }
    return MaestroCard(
        child: Column(children: [for (final item in items) itemBuilder(item)]));
  }
}
