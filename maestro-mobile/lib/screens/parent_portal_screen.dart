import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/messaging_inbox.dart';
import '../services/messaging_service.dart';
import '../services/parent_portal_service.dart';
import '../theme/maestro_theme.dart';
import '../widgets/maestro_card.dart';
import '../widgets/maestro_shell.dart';
import '../widgets/dashboard_layout.dart';
import 'messages_screen.dart';

class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen(
      {super.key,
      required this.client,
      required this.onSignOut,
      this.onSwitchTeacher,
      this.onSwitchStudent,
      this.service,
      this.inbox});

  final SupabaseClient client;
  final Future<void> Function() onSignOut;
  final VoidCallback? onSwitchTeacher;
  final VoidCallback? onSwitchStudent;
  final ParentPortalService? service;
  final MessagingInbox? inbox;

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  late final ParentPortalService service =
      widget.service ?? ParentPortalService(widget.client);
  late final MessagingInbox inbox =
      widget.inbox ?? MessagingInbox(MessagingService(widget.client))
        ..start();
  late Future<List<Map<String, dynamic>>> portals = service.loadPortals();
  Future<Map<String, dynamic>?>? profileFuture;
  String? displayName;
  int section = 0;
  String? selectedStudent;

  @override
  void initState() {
    super.initState();
    final userId = widget.client.auth.currentUser?.id;
    if (userId != null) {
      profileFuture = widget.client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      profileFuture!.then((row) {
        if (mounted) {
          setState(() => displayName = row?['display_name'] as String?);
        }
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    if (widget.inbox == null) inbox.dispose();
    super.dispose();
  }

  void refresh() => setState(() {
        selectedStudent = null;
        portals = service.loadPortals();
      });

  List<Map<String, dynamic>> rows(Object? value) => (value as List? ?? const [])
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  double amount(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String money(Object? value, String currency) =>
      '${amount(value).toStringAsFixed(2)} $currency';

  String date(Object? value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? 'Date pending' : DateFormat.yMMMd().format(parsed);
  }

  Widget home(List<Map<String, dynamic>> data) {
    final visible = data
        .where((row) =>
            selectedStudent == null || row['studentId'] == selectedStudent)
        .toList();
    final students = {
      for (final row in visible) row['studentId']: row['studentName']
    };
    final totals = <String, double>{};
    for (final row in visible) {
      if (row['canViewFinances'] == true) {
        final currency = row['currency'] as String;
        totals[currency] = (totals[currency] ?? 0) + amount(row['balance']);
      }
    }
    final upcoming = <Map<String, dynamic>>[];
    for (final row in visible.where((r) => r['canViewFinances'] == true)) {
      for (final lesson in rows(row['fees'])) {
        final lessonDate = DateTime.tryParse('${lesson['date']}');
        if (lessonDate != null &&
            !lessonDate.isBefore(DateTime.now()) &&
            lesson['status'] == 'NOTHING') {
          upcoming.add({...lesson, 'studentName': row['studentName']});
        }
      }
    }
    upcoming.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    return DashboardLayout(
      greeting:
          'Welcome, ${displayName ?? widget.client.auth.currentUser?.userMetadata?['display_name'] ?? widget.client.auth.currentUser?.email ?? 'Parent'}',
      top: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (data.length > 1) ...[
          _childSelector(data),
          const SizedBox(height: 10),
        ],
        if (students.isEmpty)
          const Text('No students linked to this account.')
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in students.entries)
              Chip(
                label: Text('${entry.value}'),
                backgroundColor: MaestroAccents.tint(
                    MaestroAccents.blue,
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).brightness),
                labelStyle: TextStyle(
                    color: MaestroAccents.foreground(
                        MaestroAccents.blue, Theme.of(context).brightness)),
                side: BorderSide.none,
              ),
          ]),
      ]),
      stats: [
        DashboardStat(
            'My Children', '${students.length}', Icons.family_restroom_outlined,
            accent: MaestroAccents.blue),
        DashboardStat(
            'Upcoming Lessons',
            visible.isNotEmpty &&
                    visible.every((r) => r['canViewFinances'] != true)
                ? '—'
                : '${upcoming.length}',
            Icons.event_note_outlined,
            accent: MaestroAccents.violet),
        DashboardStat(
            'Payments / Balance',
            totals.isEmpty
                ? '—'
                : totals.entries
                    .map((e) => money(e.value.abs(), e.key))
                    .join(' · '),
            Icons.payments_outlined,
            accent: MaestroAccents.green),
        DashboardStat('Unread Messages', '${inbox.unreadCount}',
            Icons.mark_chat_unread_outlined,
            accent: MaestroAccents.pink),
      ],
      actions: [
        DashboardAction('My Children', Icons.family_restroom_outlined,
            () => setState(() => section = 4),
            accent: MaestroAccents.blue),
        DashboardAction('Lessons', Icons.menu_book_outlined,
            () => setState(() => section = 5),
            accent: MaestroAccents.violet),
        DashboardAction('Payments', Icons.payments_outlined,
            totals.isEmpty ? null : () => setState(() => section = 1),
            accent: MaestroAccents.green),
        DashboardAction('Calendar', Icons.calendar_month_outlined,
            () => setState(() => section = 5),
            accent: MaestroAccents.orange),
        DashboardAction('Messages', Icons.chat_bubble_outline,
            () => setState(() => section = 2),
            accent: MaestroAccents.pink),
        const DashboardAction('Progress', Icons.trending_up, null,
            accent: MaestroAccents.cyan),
      ],
      sections: [
        MaestroCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upcoming Lessons',
              style: Theme.of(context).textTheme.titleMedium),
          if (upcoming.isEmpty)
            DashboardEmptyState(
              visible.any((r) => r['canViewFinances'] != true)
                  ? 'Lesson details are unavailable for this child.'
                  : 'No upcoming lessons.',
              icon: Icons.event_note_outlined,
            ),
          for (final lesson in upcoming.take(3))
            ListTile(
                title: Text('${lesson['title']}'),
                subtitle:
                    Text('${lesson['studentName']} · ${date(lesson['date'])}')),
        ])),
        MaestroCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment Information',
              style: Theme.of(context).textTheme.titleMedium),
          if (totals.isEmpty)
            const DashboardEmptyState('No payment information available.',
                icon: Icons.payments_outlined),
          for (final entry in totals.entries)
            ListTile(
                title: Text(entry.value > 0
                    ? 'Outstanding'
                    : entry.value < 0
                        ? 'Credit'
                        : 'Paid in full'),
                trailing: Text(money(entry.value.abs(), entry.key))),
        ])),
        MaestroCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Children's Progress",
              style: Theme.of(context).textTheme.titleMedium),
          const Text(
              'Progress information is not available in the parent portal yet.'),
        ])),
        MaestroCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recent Messages',
              style: Theme.of(context).textTheme.titleMedium),
          ListTile(
              title: const Text('Unread messages'),
              trailing: Text('${inbox.unreadCount}'),
              onTap: () => setState(() => section = 2)),
          for (final conversation in inbox.conversations.take(3))
            ListTile(
                title: Text('${conversation['name']}'),
                subtitle: Text('${conversation['lastMessage'] ?? 'Say hello'}'),
                onTap: () => setState(() => section = 2)),
        ])),
      ],
    );
  }

  Widget _childSelector(List<Map<String, dynamic>> data) =>
      DropdownButtonFormField<String?>(
        key: ValueKey('dashboard-child-$selectedStudent'),
        initialValue: selectedStudent,
        decoration: const InputDecoration(labelText: 'Child'),
        items: [
          const DropdownMenuItem<String?>(
              value: null, child: Text('All my children')),
          for (final row in {
            for (final r in data)
              r['studentId'] as String: r['studentName'] as String
          }.entries)
            DropdownMenuItem<String?>(value: row.key, child: Text(row.value)),
        ],
        onChanged: (value) => setState(() => selectedStudent = value),
      );

  Widget children(List<Map<String, dynamic>> data) {
    final visible = data
        .where((row) =>
            selectedStudent == null || row['studentId'] == selectedStudent)
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (data.length > 1) _childSelector(data),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        const MaestroCard(child: Text('No students linked to this account.')),
      for (final row in visible)
        MaestroCard(
            child: ListTile(
          leading: const Icon(Icons.music_note_outlined),
          title: Text('${row['studentName']}'),
          subtitle: Text('Teacher: ${row['teacherName']}'),
        )),
    ]);
  }

  Widget calendar(List<Map<String, dynamic>> data) {
    final visible = data
        .where((row) =>
            selectedStudent == null || row['studentId'] == selectedStudent)
        .toList();
    final lessons = <Map<String, dynamic>>[];
    for (final row in visible.where((r) => r['canViewFinances'] == true)) {
      for (final lesson in rows(row['fees'])) {
        lessons.add({...lesson, 'studentName': row['studentName']});
      }
    }
    lessons.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (data.length > 1) _childSelector(data),
      const SizedBox(height: 12),
      if (lessons.isEmpty)
        MaestroCard(
            child: Text(visible.any((r) => r['canViewFinances'] != true)
                ? 'Lesson details are unavailable for this child.'
                : 'No lessons to show.')),
      for (final lesson in lessons)
        MaestroCard(
            child: ListTile(
          title: Text('${lesson['title']}'),
          subtitle: Text('${lesson['studentName']} · ${date(lesson['date'])}'),
        )),
    ]);
  }

  Widget payments(List<Map<String, dynamic>> data) {
    final studentNames = <String, String>{};
    for (final row in data) {
      studentNames[row['studentId'] as String] = row['studentName'] as String;
    }
    final visible = data
        .where((row) =>
            (selectedStudent == null || row['studentId'] == selectedStudent) &&
            row['canViewFinances'] == true)
        .toList();
    final totals = <String, double>{};
    for (final row in visible) {
      final currency = row['currency'] as String;
      totals[currency] = (totals[currency] ?? 0) + amount(row['balance']);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (studentNames.isNotEmpty)
        DropdownButtonFormField<String?>(
            key: ValueKey('payments-child-$selectedStudent'),
            initialValue: selectedStudent,
            decoration: const InputDecoration(labelText: 'Child'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All my children')),
              for (final entry in studentNames.entries)
                DropdownMenuItem<String?>(
                    value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => selectedStudent = value)),
      const SizedBox(height: 12),
      for (final entry in totals.entries)
        Card(
            child: ListTile(
                title: Text(entry.value > 0
                    ? 'Outstanding balance'
                    : entry.value < 0
                        ? 'Credit balance'
                        : 'Paid in full'),
                trailing: Text(money(entry.value.abs(), entry.key)))),
      if (visible.isEmpty) const Text('No payment information available.'),
      for (final row in visible)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['studentName']} · ${row['teacherName']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          'Balance: ${money(row['balance'], row['currency'] as String)}'),
                      const SizedBox(height: 12),
                      Text('Lesson fees',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final fee in rows(row['fees']))
                        ListTile(
                            dense: true,
                            title: Text(fee['title'] as String),
                            subtitle:
                                Text('${date(fee['date'])} · ${fee['status']}'),
                            trailing: Text(money(
                                fee['amount'], row['currency'] as String))),
                      const SizedBox(height: 8),
                      Text('Recorded payments',
                          style: Theme.of(context).textTheme.titleSmall),
                      if (rows(row['payments']).isEmpty)
                        const Text('No payments recorded.'),
                      for (final payment in rows(row['payments']))
                        ListTile(
                            dense: true,
                            title: Text(date(payment['date'])),
                            subtitle: Text('${payment['method'] ?? 'Payment'}'),
                            trailing: Text(money(
                                payment['amount'], row['currency'] as String))),
                    ]))),
    ]);
  }

  Widget profile() => FutureBuilder<Map<String, dynamic>?>(
      future: profileFuture ??= widget.client
          .from('profiles')
          .select('display_name')
          .eq('id', widget.client.auth.currentUser!.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final displayName = snapshot.data?['display_name'] as String? ?? '';
        return ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
              title: const Text('Name'),
              subtitle: Text(displayName),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => editName(displayName)),
          ListTile(
              title: const Text('Email'),
              subtitle: Text(widget.client.auth.currentUser?.email ?? ''),
              trailing: const Icon(Icons.edit_outlined),
              onTap: editEmail),
          ListTile(
              title: const Text('Reset password'),
              leading: const Icon(Icons.lock_outline),
              onTap: resetPassword),
          OutlinedButton(
              onPressed: widget.onSignOut, child: const Text('Sign out')),
          if (widget.onSwitchTeacher != null)
            OutlinedButton(
                onPressed: widget.onSwitchTeacher,
                child: const Text('Teacher Portal')),
          if (widget.onSwitchStudent != null)
            OutlinedButton(
                onPressed: widget.onSwitchStudent,
                child: const Text('Student Portal')),
        ]);
      });

  Future<void> editName(String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Edit name'),
              content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save')),
              ],
            ));
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await widget.client.from('profiles').update({'display_name': value}).eq(
          'id', widget.client.auth.currentUser!.id);
      if (mounted) {
        setState(() => profileFuture = widget.client
            .from('profiles')
            .select('display_name')
            .eq('id', widget.client.auth.currentUser!.id)
            .maybeSingle());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update name: $e')));
      }
    }
  }

  Future<void> editEmail() async {
    final controller = TextEditingController(
        text: widget.client.auth.currentUser?.email ?? '');
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Change account email'),
              content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'New email')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save')),
              ],
            ));
    controller.dispose();
    if (value == null ||
        value.isEmpty ||
        value == widget.client.auth.currentUser?.email) {
      return;
    }
    try {
      await widget.client.auth.updateUser(UserAttributes(email: value));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Check your email to confirm the change.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update email: $e')));
      }
    }
  }

  Future<void> resetPassword() async {
    final email = widget.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await widget.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send reset email: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: portals,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Could not load parent portal: ${snapshot.error}'),
              TextButton(onPressed: refresh, child: const Text('Try again')),
            ])));
          }
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return const Scaffold(body: SafeArea(child: DashboardSkeleton()));
          }
          final data = snapshot.data!;
          return AnimatedBuilder(
              animation: inbox,
              builder: (context, _) => MaestroShell(
                    title: section == 0
                        ? 'Maestro'
                        : switch (section) {
                            1 => 'Payments',
                            2 => 'Messages',
                            3 => 'Profile',
                            4 => 'My Children',
                            _ => 'Calendar',
                          },
                    userName: displayName ??
                        '${widget.client.auth.currentUser?.userMetadata?['display_name'] ?? widget.client.auth.currentUser?.email ?? 'Parent'}',
                    selectedIndex: switch (section) {
                      4 => 1,
                      5 => 2,
                      2 => 3,
                      3 => 4,
                      _ => 0
                    },
                    shortcuts: [
                      if (data.any((r) => r['canViewFinances'] == true))
                        MaestroShortcut(
                            'Payments',
                            Icons.payments_outlined,
                            MaestroAccents.green,
                            () => setState(() => section = 1),
                            selected: section == 1),
                    ],
                    unreadCount: inbox.unreadCount,
                    onRefresh: refresh,
                    onProfile: () => setState(() => section = 3),
                    onSettings: () => setState(() => section = 3),
                    onSignOut: widget.onSignOut,
                    destinations: [
                      MaestroDestination('Home', Icons.home_outlined,
                          () => setState(() => section = 0)),
                      MaestroDestination(
                          'Children',
                          Icons.family_restroom_outlined,
                          () => setState(() => section = 4)),
                      MaestroDestination(
                          'Calendar',
                          Icons.calendar_month_outlined,
                          () => setState(() => section = 5)),
                      MaestroDestination('Messages', Icons.chat_bubble_outline,
                          () => setState(() => section = 2),
                          badge: inbox.unreadCount),
                    ],
                    body: IndexedStack(index: section, children: [
                      home(data),
                      payments(data),
                      section == 2
                          ? MessagesScreen(
                              client: widget.client,
                              teacher: false,
                              allowNew: false,
                              inbox: inbox)
                          : const SizedBox.shrink(),
                      section == 3 ? profile() : const SizedBox.shrink(),
                      children(data),
                      calendar(data),
                    ]),
                  ));
        },
      );
}
