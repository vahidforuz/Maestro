import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../services/studio_metrics.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudent,
  });

  final MaestroApi api;
  final Teacher teacher;
  final ValueChanged<Student> onOpenStudent;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<Student>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<List<Student>>(
          future: _future,
          builder: (context, snapshot) {
            return AsyncState<List<Student>>(
              snapshot: snapshot,
              builder: _content,
            );
          },
        ),
      ),
    );
  }

  Widget _content(List<Student> students) {
    final visible = visibleStudentsForTeacher(students, widget.teacher);
    final dated = lessonsForStudents(visible)
        .where((lesson) => lesson.course.date != null)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Calendar',
          subtitle:
              '${dated.length} dated lessons for ${widget.teacher.displayName}',
        ),
        const SizedBox(height: 18),
        Expanded(
          child: dated.isEmpty
              ? const MaestroCard(child: Text('No dated lessons found.'))
              : ListView.separated(
                  itemCount: dated.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lesson = dated[index];
                    final date = lesson.course.date;
                    return MaestroCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available),
                        title: Text(lesson.student.displayName),
                        subtitle: Text(
                          '${date == null ? 'No date' : DateFormat.yMMMd().format(date)}'
                          ' ${lesson.course.hour ?? ''} - ${lesson.course.title}',
                        ),
                        trailing: StatusBadge(label: lesson.course.status),
                        onTap: () => widget.onOpenStudent(lesson.student),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
