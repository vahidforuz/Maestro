import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/student.dart';
import '../models/student_course.dart';
import '../models/student_project.dart';
import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/status_badge.dart';

enum _CalendarView { day, week, month }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudent,
    required this.onOpenLesson,
  });

  final MaestroApi api;
  final Teacher teacher;
  final ValueChanged<Student> onOpenStudent;
  final void Function(Student student, int courseId) onOpenLesson;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<Student>> _future;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  _CalendarView _view = _CalendarView.week;
  String _query = '';

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
              onRetry: _refresh,
              builder: _content,
            );
          },
        ),
      ),
    );
  }

  Widget _content(List<Student> students) {
    final visible = visibleStudentsForTeacher(students, widget.teacher);
    final events = _filteredEvents(_eventsForStudents(visible));
    final visibleEvents = events.where(_isInVisiblePeriod).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final compact = constraints.maxWidth < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendar',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _Toolbar(
              selectedDate: _selectedDate,
              view: _view,
              compact: compact,
              onPrevious: _previous,
              onToday: _today,
              onNext: _next,
              onViewChanged: (view) => setState(() => _view = view),
              onSearchChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _CalendarSidebar(
                            selectedDate: _selectedDate,
                            events: events,
                            onSelectDate: (date) => setState(() {
                              _selectedDate = date;
                              _view = _CalendarView.day;
                            }),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _CalendarBody(
                            view: _view,
                            selectedDate: _selectedDate,
                            events: visibleEvents,
                            lessonDurationMinutes:
                                widget.teacher.defaultLessonDuration,
                            onSelectDate: _selectCalendarDate,
                            onOpenEvent: _showEventDetails,
                          ),
                        ),
                      ],
                    )
                  : _CalendarBody(
                      view: _view,
                      selectedDate: _selectedDate,
                      events: visibleEvents,
                      lessonDurationMinutes:
                          widget.teacher.defaultLessonDuration,
                      onSelectDate: _selectCalendarDate,
                      onOpenEvent: _showEventDetails,
                    ),
            ),
          ],
        );
      },
    );
  }

  void _refresh() {
    setState(() => _future = widget.api.fetchStudents());
  }

  void _selectCalendarDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      if (_view == _CalendarView.month) {
        _view = _CalendarView.day;
      }
    });
  }

  void _previous() {
    setState(() {
      _selectedDate = switch (_view) {
        _CalendarView.day => _selectedDate.subtract(const Duration(days: 1)),
        _CalendarView.week => _selectedDate.subtract(const Duration(days: 7)),
        _CalendarView.month =>
          DateTime(_selectedDate.year, _selectedDate.month - 1, 1),
      };
    });
  }

  void _today() {
    setState(() {
      _selectedDate = _dateOnly(DateTime.now());
      _future = widget.api.fetchStudents();
    });
  }

  void _next() {
    setState(() {
      _selectedDate = switch (_view) {
        _CalendarView.day => _selectedDate.add(const Duration(days: 1)),
        _CalendarView.week => _selectedDate.add(const Duration(days: 7)),
        _CalendarView.month =>
          DateTime(_selectedDate.year, _selectedDate.month + 1, 1),
      };
    });
  }

  List<_LessonEvent> _eventsForStudents(List<Student> students) {
    final events = <_LessonEvent>[];
    for (final student in students) {
      for (final project in student.projects) {
        for (var index = 0; index < project.courses.length; index++) {
          final course = project.courses[index];
          final date = course.date;
          if (date == null) continue;
          events.add(_LessonEvent(
            student: student,
            project: project,
            course: course,
            courseNumber: index + 1,
            start: _combine(date, course.hour),
            durationMinutes: widget.teacher.defaultLessonDuration,
          ));
        }
      }
    }
    events.sort((a, b) {
      final compareStart = a.start.compareTo(b.start);
      if (compareStart != 0) return compareStart;
      return a.studentName.compareTo(b.studentName);
    });
    return events;
  }

  List<_LessonEvent> _filteredEvents(List<_LessonEvent> events) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return events;
    return events.where((event) => event.matches(query)).toList();
  }

  bool _isInVisiblePeriod(_LessonEvent event) {
    final start = switch (_view) {
      _CalendarView.day => _selectedDate,
      _CalendarView.week => _startOfWeek(_selectedDate),
      _CalendarView.month => DateTime(_selectedDate.year, _selectedDate.month),
    };
    final end = switch (_view) {
      _CalendarView.day => start.add(const Duration(days: 1)),
      _CalendarView.week => start.add(const Duration(days: 7)),
      _CalendarView.month => DateTime(start.year, start.month + 1),
    };
    return !event.start.isBefore(start) && event.start.isBefore(end);
  }

  Future<void> _showEventDetails(_LessonEvent event) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.studentName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusBadge(label: event.statusLabel),
                ],
              ),
              const SizedBox(height: 10),
              _DetailLine(label: 'Project', value: event.project.name),
              _DetailLine(label: 'Course', value: event.courseLabel),
              _DetailLine(
                label: 'Date',
                value: DateFormat.yMMMMd().format(event.start),
              ),
              _DetailLine(label: 'Time', value: event.timeRange),
              if (event.pieces.isNotEmpty)
                _DetailLine(label: 'Pieces', value: event.pieces.join(', ')),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenLesson(event.student, event.courseId);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Lesson'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenStudent(event.student);
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Open Student'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selectedDate,
    required this.view,
    required this.compact,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    required this.onViewChanged,
    required this.onSearchChanged,
  });

  final DateTime selectedDate;
  final _CalendarView view;
  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final ValueChanged<_CalendarView> onViewChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 6),
        OutlinedButton(onPressed: onToday, child: const Text('Today')),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Next',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
    final views = SegmentedButton<_CalendarView>(
      selected: {view},
      showSelectedIcon: false,
      onSelectionChanged: (value) => onViewChanged(value.first),
      segments: const [
        ButtonSegment(value: _CalendarView.day, label: Text('Day')),
        ButtonSegment(value: _CalendarView.week, label: Text('Week')),
        ButtonSegment(value: _CalendarView.month, label: Text('Month')),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_periodTitle(selectedDate, view),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            navigation,
            const Spacer(),
            _SearchIcon(onSearchChanged)
          ]),
          const SizedBox(height: 10),
          views,
        ],
      );
    }

    return Row(
      children: [
        navigation,
        const SizedBox(width: 16),
        Text(
          _periodTitle(selectedDate, view),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        views,
        const SizedBox(width: 12),
        SizedBox(
          width: 230,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon(this.onSearchChanged);

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Search',
      onPressed: () async {
        final value = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('Search lessons'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'Student, project, piece'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Search'),
                ),
              ],
            );
          },
        );
        if (value != null) onSearchChanged(value);
      },
      icon: const Icon(Icons.search),
    );
  }
}

class _CalendarSidebar extends StatelessWidget {
  const _CalendarSidebar({
    required this.selectedDate,
    required this.events,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events
        .where((event) => _isSameDay(event.start, selectedDate))
        .take(5)
        .toList();
    return Column(
      children: [
        MaestroCard(
          child: _MiniMonth(
            selectedDate: selectedDate,
            events: events,
            onSelectDate: onSelectDate,
          ),
        ),
        const SizedBox(height: 12),
        MaestroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming Lessons',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (dayEvents.isEmpty)
                const Text('No lessons scheduled.',
                    style: TextStyle(color: MaestroColors.muted))
              else
                for (final event in dayEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 48, child: Text(event.startTime)),
                        Expanded(
                          child: Text(
                            event.studentName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.view,
    required this.selectedDate,
    required this.events,
    required this.lessonDurationMinutes,
    required this.onSelectDate,
    required this.onOpenEvent,
  });

  final _CalendarView view;
  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final int lessonDurationMinutes;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<_LessonEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      _CalendarView.day => _DayView(
          selectedDate: selectedDate,
          events: events,
          lessonDurationMinutes: lessonDurationMinutes,
          onOpenEvent: onOpenEvent,
        ),
      _CalendarView.week => _WeekView(
          selectedDate: selectedDate,
          events: events,
          lessonDurationMinutes: lessonDurationMinutes,
          onOpenEvent: onOpenEvent,
        ),
      _CalendarView.month => _MonthView(
          selectedDate: selectedDate,
          events: events,
          onSelectDate: onSelectDate,
          onOpenEvent: onOpenEvent,
        ),
    };
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.selectedDate,
    required this.events,
    required this.lessonDurationMinutes,
    required this.onOpenEvent,
  });

  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final int lessonDurationMinutes;
  final ValueChanged<_LessonEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd().format(selectedDate),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: events.isEmpty
                ? const _EmptyPeriod()
                : SingleChildScrollView(
                    child: _Timeline(
                      days: [selectedDate],
                      events: events,
                      lessonDurationMinutes: lessonDurationMinutes,
                      onOpenEvent: onOpenEvent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.selectedDate,
    required this.events,
    required this.lessonDurationMinutes,
    required this.onOpenEvent,
  });

  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final int lessonDurationMinutes;
  final ValueChanged<_LessonEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _startOfWeek(selectedDate).add(Duration(days: index)),
    );
    return MaestroCard(
      child: events.isEmpty
          ? const _EmptyPeriod()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 980,
                child: SingleChildScrollView(
                  child: _Timeline(
                    days: days,
                    events: events,
                    lessonDurationMinutes: lessonDurationMinutes,
                    onOpenEvent: onOpenEvent,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.days,
    required this.events,
    required this.lessonDurationMinutes,
    required this.onOpenEvent,
  });

  final List<DateTime> days;
  final List<_LessonEvent> events;
  final int lessonDurationMinutes;
  final ValueChanged<_LessonEvent> onOpenEvent;

  static const double _hourHeight = 78;
  static const double _headerHeight = 46;
  static const double _timeColumnWidth = 58;
  static const int _startHour = 8;
  static const int _endHour = 21;

  @override
  Widget build(BuildContext context) {
    const totalHeight = _headerHeight + (_endHour - _startHour) * _hourHeight;
    final dayWidth = days.length == 1 ? 560.0 : 126.0;
    final now = DateTime.now();
    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Stack(
              children: [
                for (var hour = _startHour; hour <= _endHour; hour++)
                  Positioned(
                    top: _headerHeight + (hour - _startHour) * _hourHeight - 8,
                    right: 8,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: const TextStyle(
                        color: MaestroColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: MaestroColors.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          _DayHeader(day: day),
                          for (var hour = _startHour; hour < _endHour; hour++)
                            const SizedBox(
                              height: _hourHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top:
                                        BorderSide(color: MaestroColors.border),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_isSameDay(now, day) &&
                      now.hour >= _startHour &&
                      now.hour < _endHour)
                    Positioned(
                      top: _headerHeight +
                          ((now.hour + now.minute / 60) - _startHour) *
                              _hourHeight,
                      left: 0,
                      right: 0,
                      child: Container(height: 2, color: MaestroColors.primary),
                    ),
                  for (final event in events.where((event) =>
                      _isSameDay(event.start, day) &&
                      event.start.hour >= _startHour &&
                      event.start.hour < _endHour))
                    Positioned(
                      top: _headerHeight +
                          ((event.start.hour + event.start.minute / 60) -
                                  _startHour) *
                              _hourHeight +
                          3,
                      left: 6,
                      right: 6,
                      height: _eventHeight(lessonDurationMinutes),
                      child: _EventCard(event: event, onTap: onOpenEvent),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _eventHeight(int duration) {
    final minutes = duration <= 0 ? 45 : duration;
    return (minutes / 60 * _hourHeight).clamp(48, 120).toDouble();
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final today = _isSameDay(day, DateTime.now());
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: today ? MaestroColors.subtleBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        DateFormat('EEE d').format(day).toUpperCase(),
        style: TextStyle(
          color: today ? MaestroColors.primary : MaestroColors.text,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.selectedDate,
    required this.events,
    required this.onSelectDate,
    required this.onOpenEvent,
  });

  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<_LessonEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final days = _monthGridDays(selectedDate);
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMM().format(selectedDate),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    for (final label in const [
                      'MON',
                      'TUE',
                      'WED',
                      'THU',
                      'FRI',
                      'SAT',
                      'SUN'
                    ])
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MaestroColors.muted,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    itemCount: days.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final dayEvents = events
                          .where((event) => _isSameDay(event.start, day))
                          .toList();
                      return _MonthCell(
                        day: day,
                        inMonth: day.month == selectedDate.month,
                        selected: _isSameDay(day, selectedDate),
                        events: dayEvents,
                        onSelectDate: onSelectDate,
                        onOpenEvent: onOpenEvent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.events,
    required this.onSelectDate,
    required this.onOpenEvent,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final List<_LessonEvent> events;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<_LessonEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final today = _isSameDay(day, DateTime.now());
    return InkWell(
      onTap: () => onSelectDate(day),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? MaestroColors.subtleBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: today ? MaestroColors.primary : MaestroColors.border,
            width: today ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: inMonth ? MaestroColors.text : MaestroColors.muted,
                fontWeight:
                    today || selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final event in events.take(2))
              InkWell(
                onTap: () => onOpenEvent(event),
                child: Text(
                  event.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MaestroColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (events.length > 2)
              Text(
                '+${events.length - 2} more',
                style: const TextStyle(
                  color: MaestroColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.selectedDate,
    required this.events,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final List<_LessonEvent> events;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = _monthGridDays(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMM().format(selectedDate),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MaestroColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final hasEvent =
                events.any((event) => _isSameDay(event.start, day));
            final selected = _isSameDay(day, selectedDate);
            final today = _isSameDay(day, DateTime.now());
            return InkWell(
              onTap: () => onSelectDate(day),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selected ? MaestroColors.primary : Colors.transparent,
                  border: Border.all(
                    color: today ? MaestroColors.primary : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : day.month == selectedDate.month
                                ? MaestroColors.text
                                : MaestroColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasEvent)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                selected ? Colors.white : MaestroColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final _LessonEvent event;
  final ValueChanged<_LessonEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(event.statusLabel);
    return Material(
      color: _statusColor(tone).$1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onTap(event),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _statusColor(tone).$2),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: MaestroColors.text, fontSize: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${event.instrumentLabel} • ${event.courseLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  event.timeRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  event.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _statusColor(tone).$2,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
                if (event.pendingReviewCount > 0)
                  Text(
                    '${event.pendingReviewCount} reviews pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MaestroColors.warningText,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child:
                Text(label, style: const TextStyle(color: MaestroColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No lessons scheduled for this period.',
        style: TextStyle(color: MaestroColors.muted),
      ),
    );
  }
}

class _LessonEvent {
  const _LessonEvent({
    required this.student,
    required this.project,
    required this.course,
    required this.courseNumber,
    required this.start,
    required this.durationMinutes,
  });

  final Student student;
  final StudentProject project;
  final StudentCourse course;
  final int courseNumber;
  final DateTime start;
  final int durationMinutes;

  int get studentId => student.id;
  int get projectId => project.id;
  int get courseId => course.id;
  String get studentName => student.displayName;
  String get courseLabel =>
      course.title.trim().isEmpty ? 'Course $courseNumber' : course.title;
  String get startTime => DateFormat.Hm().format(start);
  String get timeRange {
    final end = start
        .add(Duration(minutes: durationMinutes <= 0 ? 45 : durationMinutes));
    return '${DateFormat.Hm().format(start)} - ${DateFormat.Hm().format(end)}';
  }

  String get statusLabel {
    final status = course.status.trim().toUpperCase();
    if (status == 'NOTHING' || status.isEmpty) {
      return start.isAfter(DateTime.now()) ? 'UPCOMING' : 'NOT SET';
    }
    return status == 'CANCELED' ? 'CANCELLED' : status;
  }

  String get instrumentLabel => student.instrument ?? 'Lesson';
  List<String> get pieces => project.pieces;
  int get pendingReviewCount {
    var count = 0;
    for (final studentProject in student.projects) {
      for (final sourceCourse in studentProject.courses) {
        if (sourceCourse.id == course.id) continue;
        for (final note in sourceCourse.notes) {
          if (note.reviewStatus != 'PENDING') continue;
          if (note.targetCourseId == course.id) {
            count++;
          } else if (note.targetCourseId == null &&
              note.reviewDate != null &&
              course.date != null &&
              !note.reviewDate!.isAfter(course.date!)) {
            count++;
          }
        }
      }
    }
    return count;
  }

  bool matches(String query) {
    final haystack = [
      studentName,
      courseLabel,
      project.name,
      instrumentLabel,
      ...pieces,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

DateTime _combine(DateTime date, String? hour) {
  final parts = (hour ?? '').split(':');
  final parsedHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final parsedMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, parsedHour, parsedMinute);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) {
  final date = _dateOnly(value);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

List<DateTime> _monthGridDays(DateTime selectedDate) {
  final monthStart = DateTime(selectedDate.year, selectedDate.month);
  final first = _startOfWeek(monthStart);
  return List.generate(42, (index) => first.add(Duration(days: index)));
}

String _periodTitle(DateTime selectedDate, _CalendarView view) {
  return switch (view) {
    _CalendarView.day => DateFormat.yMMMMd().format(selectedDate),
    _CalendarView.week => _weekTitle(selectedDate),
    _CalendarView.month => DateFormat.yMMMM().format(selectedDate),
  };
}

String _weekTitle(DateTime selectedDate) {
  final start = _startOfWeek(selectedDate);
  final end = start.add(const Duration(days: 6));
  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat.MMMM().format(start)} ${start.day} - ${end.day}, ${end.year}';
  }
  return '${DateFormat.MMMd().format(start)} - ${DateFormat.yMMMd().format(end)}';
}

StatusTone _statusTone(String status) {
  return switch (status.toUpperCase()) {
    'PRESENT' => StatusTone.success,
    'UPCOMING' || 'NOT SET' => StatusTone.warning,
    'ABSENT' || 'CANCELLED' => StatusTone.danger,
    _ => StatusTone.neutral,
  };
}

(Color, Color) _statusColor(StatusTone tone) {
  return switch (tone) {
    StatusTone.success => (MaestroColors.successBg, MaestroColors.successText),
    StatusTone.warning => (MaestroColors.warningBg, MaestroColors.warningText),
    StatusTone.danger => (MaestroColors.dangerBg, MaestroColors.dangerText),
    StatusTone.neutral => (MaestroColors.neutralBg, MaestroColors.muted),
  };
}
