import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_data_source.dart';
import '../services/messaging_inbox.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/dashboard_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudents,
    required this.onOpenStudent,
    required this.onOpenCalendar,
    required this.onAddStudent,
    required this.onOpenPayments,
    required this.onOpenMessages,
    this.inbox,
  });

  final MaestroDataSource api;
  final Teacher teacher;
  final VoidCallback onOpenStudents;
  final ValueChanged<Student> onOpenStudent;
  final VoidCallback onOpenCalendar;
  final VoidCallback onAddStudent;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenMessages;
  final MessagingInbox? inbox;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const DashboardSkeleton();
          }
          return AsyncState<_DashboardData>(
            snapshot: snapshot,
            builder: _content,
          );
        },
      ),
    );
  }

  Widget _content(_DashboardData data) {
    final students = visibleStudentsForTeacher(data.students, widget.teacher);
    final payments =
        visiblePaymentsForTeacher(data.payments, data.students, widget.teacher);
    final today = DateTime.now();
    final monthPayments = payments.where((payment) {
      final date = payment.paymentDate;
      return date != null &&
          date.year == today.year &&
          date.month == today.month;
    }).toList();
    final monthLessons = lessonsForStudents(students).where((lesson) {
      final date = lesson.course.date;
      return date != null &&
          date.year == today.year &&
          date.month == today.month;
    }).toList();
    final totalRevenue = monthPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );

    return DashboardLayout(
      greeting: 'Welcome, ${widget.teacher.displayName}',
      stats: [
        DashboardStat(
            'Total Students', '${students.length}', Icons.people_outline,
            accent: MaestroAccents.blue),
        DashboardStat('Lessons This Month', '${monthLessons.length}',
            Icons.event_note_outlined,
            accent: MaestroAccents.violet),
        DashboardStat('Payments This Month', '${monthPayments.length}',
            Icons.payments_outlined,
            accent: MaestroAccents.green),
        DashboardStat(
            'Revenue This Month',
            NumberFormat.simpleCurrency().format(totalRevenue),
            Icons.trending_up,
            accent: MaestroAccents.green),
      ],
      actions: [
        DashboardAction(
            'Add Student', Icons.person_add_alt_1, widget.onAddStudent,
            accent: MaestroAccents.blue),
        DashboardAction('Schedule Lesson', Icons.event_available_outlined,
            widget.onOpenCalendar,
            accent: MaestroAccents.orange),
        DashboardAction(
            'Record Payment', Icons.add_card_outlined, widget.onOpenPayments,
            accent: MaestroAccents.green),
        DashboardAction(
            'Add Note', Icons.note_add_outlined, widget.onOpenStudents,
            accent: MaestroAccents.violet),
        DashboardAction(
            'Messages', Icons.chat_bubble_outline, widget.onOpenMessages,
            accent: MaestroAccents.pink),
        const DashboardAction('Reports', Icons.bar_chart_outlined, null,
            accent: MaestroAccents.cyan),
      ],
      sections: [
        _TodayCard(students: students, onOpenStudent: widget.onOpenStudent),
        _UpcomingCard(students: students, onOpenStudent: widget.onOpenStudent),
        _ReviewCard(students: students, onOpenStudent: widget.onOpenStudent),
        _PaymentAttentionCard(
            students: students,
            payments: payments,
            onOpenStudent: widget.onOpenStudent),
        _RecentMessagesCard(
            inbox: widget.inbox, onOpenMessages: widget.onOpenMessages),
      ],
    );
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.api.fetchStudents(),
      widget.api.fetchPayments(),
    ]);
    return _DashboardData(
      students: results[0] as List<Student>,
      payments: results[1] as List<Payment>,
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.students, required this.onOpenStudent});

  final List<Student> students;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaysLessons = lessonsForStudents(students).where((lesson) {
      final date = lesson.course.date;
      return date != null && DateTime(date.year, date.month, date.day) == today;
    }).toList();

    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Lessons",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (todaysLessons.isEmpty)
            const DashboardEmptyState('No lessons scheduled for today.',
                icon: Icons.event_available_outlined)
          else
            for (final lesson in todaysLessons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lesson.student.displayName),
                subtitle: Text(
                    '${lesson.course.hour ?? 'No time'} - ${lesson.course.title}'),
                trailing: StatusBadge(label: lesson.course.status),
                onTap: () => onOpenStudent(lesson.student),
              ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.students, required this.onOpenStudent});
  final List<Student> students;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = lessonsForStudents(students)
        .where((lesson) {
          final date = lesson.course.date;
          return date != null &&
              date.isAfter(now) &&
              lesson.course.status == 'NOTHING';
        })
        .take(5)
        .toList();
    return MaestroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Upcoming Lessons',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (upcoming.isEmpty)
        const DashboardEmptyState('No upcoming lessons.',
            icon: Icons.event_note_outlined)
      else
        for (final lesson in upcoming)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lesson.student.displayName),
            subtitle: Text(
                '${DateFormat.yMMMd().format(lesson.course.date!)} · ${lesson.course.title}'),
            onTap: () => onOpenStudent(lesson.student),
          ),
    ]));
  }
}

class _RecentMessagesCard extends StatelessWidget {
  const _RecentMessagesCard(
      {required this.inbox, required this.onOpenMessages});
  final MessagingInbox? inbox;
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) => inbox == null
      ? _card(context)
      : AnimatedBuilder(
          animation: inbox!, builder: (context, _) => _card(context));

  Widget _card(BuildContext context) => MaestroCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Messages',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (inbox != null) Text('${inbox!.unreadCount} unread'),
          const SizedBox(height: 10),
          if (inbox == null || inbox!.conversations.isEmpty)
            const DashboardEmptyState('No recent messages.',
                icon: Icons.chat_bubble_outline)
          else
            for (final row in inbox!.conversations.take(3))
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${row['name'] ?? 'Conversation'}'),
                  subtitle: Text('${row['lastMessage'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: onOpenMessages),
          TextButton(
              onPressed: onOpenMessages, child: const Text('View messages')),
        ],
      ));
}

class _PaymentAttentionCard extends StatelessWidget {
  const _PaymentAttentionCard({
    required this.students,
    required this.payments,
    required this.onOpenStudent,
  });

  final List<Student> students;
  final List<Payment> payments;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final attention = [...students]..sort((a, b) =>
        paymentBalance(a, payments).compareTo(paymentBalance(b, payments)));
    final visible = attention
        .where((student) => paymentBalance(student, payments) < 0)
        .take(6);

    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Attention',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const DashboardEmptyState('No student balances need attention.',
                icon: Icons.check_circle_outline)
          else
            for (final student in visible)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(student.displayName),
                subtitle: Text(
                    'Balance: ${NumberFormat.simpleCurrency().format(paymentBalance(student, payments))}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenStudent(student),
              ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.students, required this.onOpenStudent});

  final List<Student> students;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final withNotes = students
        .where((student) =>
            student.courses.any((course) => course.notes.isNotEmpty))
        .take(6)
        .toList();

    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes to Review',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (withNotes.isEmpty)
            const DashboardEmptyState('No review notes found.',
                icon: Icons.rate_review_outlined)
          else
            for (final student in withNotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(student.displayName),
                subtitle: Text(
                    '${student.courses.expand((course) => course.notes).length} notes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenStudent(student),
              ),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({required this.students, required this.payments});

  final List<Student> students;
  final List<Payment> payments;
}
