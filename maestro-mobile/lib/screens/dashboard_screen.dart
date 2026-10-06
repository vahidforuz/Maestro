import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudents,
    required this.onOpenStudent,
    required this.onOpenCalendar,
    required this.onAddStudent,
  });

  final MaestroApi api;
  final Teacher teacher;
  final VoidCallback onOpenStudents;
  final ValueChanged<Student> onOpenStudent;
  final VoidCallback onOpenCalendar;
  final VoidCallback onAddStudent;

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

    return ListView(
      children: [
        SectionHeader(
          title: 'Dashboard',
          subtitle:
              'Signed in as ${widget.teacher.displayName} - Teacher ID ${widget.teacher.id}',
          trailing: Wrap(
            spacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: widget.onAddStudent,
                icon: const Icon(Icons.add),
                label: const Text('Add Student'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenCalendar,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Calendar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _StatCard(
                label: 'Total Students', value: students.length.toString()),
            _StatCard(
                label: 'Lessons This Month',
                value: monthLessons.length.toString()),
            _StatCard(
                label: 'Payments This Month',
                value: monthPayments.length.toString()),
            _StatCard(
                label: 'Revenue This Month',
                value: NumberFormat.simpleCurrency().format(totalRevenue)),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 900;
            final children = [
              Expanded(
                  child: _TodayCard(
                      students: students, onOpenStudent: widget.onOpenStudent)),
              const SizedBox(width: 16, height: 16),
              Expanded(
                  child: _ReviewCard(
                      students: students, onOpenStudent: widget.onOpenStudent)),
              const SizedBox(width: 16, height: 16),
              Expanded(
                  child: _PaymentAttentionCard(
                      students: students,
                      payments: payments,
                      onOpenStudent: widget.onOpenStudent)),
            ];
            if (twoColumn) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children);
            }
            return Column(
              children: [
                children[0],
                children[1],
                children[2],
                children[3],
                children[4],
              ],
            );
          },
        ),
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
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: MaestroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: MaestroColors.muted)),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
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
            const Text('No lessons scheduled for today.')
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
        .where((student) => paymentBalance(student, payments) <= 0)
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
            const Text('No student balances need attention.')
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
            const Text('No review notes found.')
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
