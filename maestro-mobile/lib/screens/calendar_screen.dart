import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_availability.dart';
import '../models/time_block.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../models/student_project.dart';
import '../models/teacher.dart';
import '../services/maestro_data_source.dart';
import '../services/calendar_availability_data_source.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/status_badge.dart';
import 'share_availability_dialog.dart';
import 'export_calendar_dialog.dart';
import 'time_block_dialog.dart';

enum _CalendarView { day, week, month }

enum _CalendarContent { lessons, availability }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudent,
    required this.onOpenLesson,
    this.onTeacherChanged,
  });

  final MaestroDataSource api;
  final Teacher teacher;
  final ValueChanged<Student> onOpenStudent;
  final void Function(Student student, int courseId) onOpenLesson;
  final ValueChanged<Teacher>? onTeacherChanged;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<Student>> _future;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  _CalendarView _view = _CalendarView.week;
  _CalendarContent _contentView = _CalendarContent.lessons;
  Future<List<AvailabilityPeriod>>? _availabilityFuture;
  Future<List<TimeBlock>>? _blocksFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchStudents();
    _loadAvailability();
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
    if (_contentView != _CalendarContent.lessons) {
      return _availabilityContent(students);
    }
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
            _contentPicker(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _shareAvailability,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Availability')),
            TextButton.icon(
                onPressed: () => _exportCalendar(students),
                icon: const Icon(Icons.ios_share),
                label: const Text('Export Calendar')),
            TextButton.icon(
                onPressed: _calendarSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Calendar Settings')),
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
    setState(() {
      _future = widget.api.fetchStudents();
      _loadAvailability();
    });
  }

  void _loadAvailability() {
    if (widget.api is CalendarAvailabilityDataSource) {
      final source = widget.api as CalendarAvailabilityDataSource;
      final start = _startOfWeek(_selectedDate);
      _availabilityFuture =
          source.fetchAvailability(start, _addCalendarDays(start, 6));
      _blocksFuture = source.fetchTimeBlocks(start, _addCalendarDays(start, 6));
    }
  }

  void _shareAvailability() {
    if (widget.api is! CalendarAvailabilityDataSource) return;
    showDialog<void>(
        context: context,
        builder: (context) => ShareAvailabilityDialog(
            source: widget.api as CalendarAvailabilityDataSource));
  }

  void _exportCalendar(List<Student> students) {
    if (widget.api is! CalendarAvailabilityDataSource) return;
    final events =
        _eventsForStudents(visibleStudentsForTeacher(students, widget.teacher));
    showDialog<void>(
        context: context,
        builder: (context) => ExportCalendarDialog(
              source: widget.api as CalendarAvailabilityDataSource,
              teacherId: widget.teacher.id,
              timezone: widget.teacher.timezone,
              lessons: [
                for (final event in events)
                  if (event.course.hour != null &&
                      event.course.status != 'CANCELED')
                    CalendarExportLesson(
                        id: event.courseId,
                        date: event.start,
                        startMinute: event.start.hour * 60 + event.start.minute,
                        durationMinutes: event.durationMinutes,
                        teacherLabel: event.studentName),
              ],
            ));
  }

  Future<void> _calendarSettings() async {
    final controller = TextEditingController(text: widget.teacher.timezone);
    final timezone = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Calendar Settings'),
              content: SizedBox(
                  width: 380,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Enter the IANA timezone used for lessons and availability.'),
                    const SizedBox(height: 12),
                    TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            labelText: 'Timezone',
                            hintText: 'America/Toronto')),
                  ])),
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
    if (timezone == null || timezone.isEmpty || !mounted) return;
    try {
      final teacher = await widget.api
          .updateTeacher(widget.teacher.id, {'timezone': timezone});
      widget.onTeacherChanged?.call(teacher);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update timezone: $error')));
      }
    }
  }

  Widget _contentPicker() => SegmentedButton<_CalendarContent>(
        selected: {_contentView},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            setState(() => _contentView = selection.first),
        segments: const [
          ButtonSegment(
              value: _CalendarContent.lessons, label: Text('Lessons')),
          ButtonSegment(
              value: _CalendarContent.availability,
              label: Text('Availability')),
        ],
      );

  Widget _availabilityContent(List<Student> students) {
    final events =
        _eventsForStudents(visibleStudentsForTeacher(students, widget.teacher));
    final busy = <BusyPeriod>[
      for (final event in events)
        if (event.course.status != 'CANCELED' && event.course.hour != null)
          BusyPeriod(
            date: event.start,
            startMinute: event.start.hour * 60 + event.start.minute,
            endMinute: event.start.hour * 60 +
                event.start.minute +
                event.durationMinutes,
          ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Calendar',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _contentPicker(),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                  onPressed: _previous,
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left)),
              OutlinedButton(onPressed: _today, child: const Text('Today')),
              IconButton.filledTonal(
                  onPressed: _next,
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right)),
              Text(_weekTitle(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(widget.teacher.timezone,
                  style: const TextStyle(color: MaestroColors.muted)),
            ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () => _openPeriodDialog(
                  _selectedDate, 9 * 60, 17 * 60, true, null, students),
              icon: const Icon(Icons.add),
              label: const Text('Add Availability')),
          OutlinedButton.icon(
              onPressed: () => _openTimeBlockDialog(
                  _selectedDate, 9 * 60, 10 * 60, students),
              icon: const Icon(Icons.block),
              label: const Text('+ Block Time')),
          for (final preset in ['Sleep', 'Vacation', 'Day Off'])
            ActionChip(
                label: Text(preset),
                onPressed: () => _openTimeBlockDialog(
                    _selectedDate, 9 * 60, 10 * 60, students,
                    preset: preset)),
          OutlinedButton.icon(
              onPressed: _shareAvailability,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Availability')),
          OutlinedButton.icon(
              onPressed: () => _exportCalendar(students),
              icon: const Icon(Icons.ios_share),
              label: const Text('Export Calendar')),
          OutlinedButton.icon(
              onPressed: _calendarSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Calendar Settings')),
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: _availabilityFuture == null
                ? const Center(
                    child: Text(
                        'Availability requires a Supabase teacher account.'))
                : FutureBuilder<List<AvailabilityPeriod>>(
                    future: _availabilityFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Could not load availability: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final periods = snapshot.data!;
                      final start = _startOfWeek(_selectedDate);
                      return FutureBuilder<List<TimeBlock>>(
                        future: _blocksFuture,
                        builder: (context, blocksSnapshot) {
                          if (blocksSnapshot.hasError) {
                            return Center(
                                child: Text(
                                    'Could not load blocked time: ${blocksSnapshot.error}'));
                          }
                          if (!blocksSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final blocks = blocksSnapshot.data!;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                                width: 1050,
                                child: SingleChildScrollView(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var index = 0; index < 7; index++)
                                        SizedBox(
                                            width: 150,
                                            child: _AvailabilityDay(
                                              day: _addCalendarDays(
                                                  start, index),
                                              periods: periods,
                                              busy: busy,
                                              blocks: blocks,
                                              events: events
                                                  .where((event) =>
                                                      event.course.status !=
                                                          'CANCELED' &&
                                                      event.course.hour != null)
                                                  .toList(),
                                              onSelect: (day, from, to) =>
                                                  _chooseRangeAction(day, from,
                                                      to, periods, students),
                                              onBlockEdit: (occurrence) =>
                                                  _openTimeBlockDialog(
                                                      _addCalendarDays(
                                                          start, index),
                                                      occurrence.start.hour *
                                                              60 +
                                                          occurrence
                                                              .start.minute,
                                                      occurrence.end.hour * 60 +
                                                          occurrence.end.minute,
                                                      students,
                                                      occurrence: occurrence),
                                              onEdit: (period) =>
                                                  _openPeriodDialog(
                                                      _addCalendarDays(
                                                          start, index),
                                                      period.startMinute,
                                                      period.endMinute,
                                                      period.available,
                                                      periods,
                                                      students,
                                                      existing: period),
                                              onCopy: () => _copyDay(
                                                  _addCalendarDays(
                                                      start, index)),
                                            )),
                                    ],
                                  ),
                                )),
                          );
                        },
                      );
                    },
                  )),
      ]);
    });
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
      if (_contentView != _CalendarContent.lessons) {
        _selectedDate = _addCalendarDays(_selectedDate, -7);
        _loadAvailability();
        return;
      }
      _selectedDate = switch (_view) {
        _CalendarView.day => _addCalendarDays(_selectedDate, -1),
        _CalendarView.week => _addCalendarDays(_selectedDate, -7),
        _CalendarView.month =>
          DateTime(_selectedDate.year, _selectedDate.month - 1, 1),
      };
    });
  }

  void _today() {
    setState(() {
      _selectedDate = _dateOnly(DateTime.now());
      _future = widget.api.fetchStudents();
      _loadAvailability();
    });
  }

  void _next() {
    setState(() {
      if (_contentView != _CalendarContent.lessons) {
        _selectedDate = _addCalendarDays(_selectedDate, 7);
        _loadAvailability();
        return;
      }
      _selectedDate = switch (_view) {
        _CalendarView.day => _addCalendarDays(_selectedDate, 1),
        _CalendarView.week => _addCalendarDays(_selectedDate, 7),
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
            courseNumber: student.courseNumberForId(course.id),
            start: _combine(date, course.hour),
            durationMinutes:
                course.durationMinutes ?? widget.teacher.defaultLessonDuration,
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
      _CalendarView.day => _addCalendarDays(start, 1),
      _CalendarView.week => _addCalendarDays(start, 7),
      _CalendarView.month => DateTime(start.year, start.month + 1),
    };
    return !event.start.isBefore(start) && event.start.isBefore(end);
  }

  Future<void> _openPeriodDialog(
      DateTime day,
      int initialStart,
      int initialEnd,
      bool initiallyAvailable,
      List<AvailabilityPeriod>? current,
      List<Student> students,
      {AvailabilityPeriod? existing}) async {
    if (widget.api is! CalendarAvailabilityDataSource) return;
    final source = widget.api as CalendarAvailabilityDataSource;
    final weekStart = _startOfWeek(day);
    final periods = current ??
        await source.fetchAvailability(
            weekStart, _addCalendarDays(weekStart, 6));
    if (!mounted) return;
    final startController =
        TextEditingController(text: clockLabel(initialStart));
    final endController = TextEditingController(
        text: initialEnd == 1440 ? '24:00' : clockLabel(initialEnd));
    var recurring = existing?.weekday != null || existing == null;
    var available = initiallyAvailable;
    var fullDay = initialStart == 0 && initialEnd == 1440;
    String? error;
    final result = await showDialog<_PeriodDraft>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) {
        return AlertDialog(
          title: Text(existing == null
              ? 'Add calendar period'
              : 'Edit calendar period'),
          content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat.yMMMMEEEEd().format(day)),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                      selected: {available},
                      onSelectionChanged: (value) =>
                          update(() => available = value.first),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Available')),
                        ButtonSegment(value: false, label: Text('Unavailable')),
                      ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: recurring,
                    decoration: const InputDecoration(labelText: 'Apply to'),
                    items: const [
                      DropdownMenuItem(
                          value: false, child: Text('This date only')),
                      DropdownMenuItem(
                          value: true,
                          child: Text('This weekday, from this date')),
                    ],
                    onChanged: existing == null
                        ? (value) => update(() => recurring = value!)
                        : null,
                  ),
                  if (existing?.weekday != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'This weekly rule will change from '
                            '${DateFormat.yMMMd().format(day)} onward. Earlier weeks stay as they are.',
                            style:
                                const TextStyle(color: MaestroColors.muted))),
                  CheckboxListTile(
                      value: fullDay,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entire day'),
                      onChanged: (value) =>
                          update(() => fullDay = value ?? false)),
                  if (!fullDay)
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: startController,
                              decoration: const InputDecoration(
                                  labelText: 'Start HH:MM'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: endController,
                              decoration: const InputDecoration(
                                  labelText: 'End HH:MM'))),
                    ]),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(error!,
                            style: const TextStyle(color: Colors.red))),
                ],
              ))),
          actions: [
            if (existing != null)
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const _PeriodDraft.delete()),
                  child: const Text('Delete')),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final start = fullDay ? 0 : parseClock(startController.text);
                  final end = fullDay
                      ? 1440
                      : endController.text.trim() == '24:00'
                          ? 1440
                          : parseClock(endController.text);
                  if (start == null || end == null || start >= end) {
                    update(() => error =
                        'Enter a valid range with the start before the end.');
                    return;
                  }
                  if (periods.any((period) =>
                      period.id != existing?.id &&
                      period.available == available &&
                      (recurring
                          ? period.weekday == day.weekday && period.date == null
                          : period.date != null &&
                              _isSameDay(period.date!, day)) &&
                      period.startMinute < end &&
                      period.endMinute > start &&
                      period.appliesTo(day))) {
                    update(() => error =
                        'This overlaps another period of the same type.');
                    return;
                  }
                  Navigator.pop(
                      context, _PeriodDraft(recurring, available, start, end));
                },
                child: const Text('Save')),
          ],
        );
      }),
    );
    startController.dispose();
    endController.dispose();
    if (result == null || !mounted) return;
    try {
      if (result.delete) {
        if (existing!.weekday != null) {
          await source.changeRecurringAvailability(
              id: existing.id,
              fromDate: day,
              startMinute: existing.startMinute,
              endMinute: existing.endMinute,
              available: existing.available,
              delete: true);
        } else {
          await source.deleteAvailability(existing.id, recurring: false);
        }
      } else {
        if (!result.available) {
          final conflicts = _eventsForStudents(
                  visibleStudentsForTeacher(students, widget.teacher))
              .where((event) {
            if (event.course.status == 'CANCELED' ||
                event.course.hour == null) {
              return false;
            }
            final matches = result.recurring
                ? event.start.weekday == day.weekday &&
                    dayNumber(event.start) >= dayNumber(day)
                : _isSameDay(event.start, day);
            final start = event.start.hour * 60 + event.start.minute;
            return matches &&
                start < result.end &&
                start + event.durationMinutes > result.start;
          }).length;
          if (conflicts > 0) {
            final proceed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Existing lessons overlap'),
                      content: Text(
                          '$conflicts scheduled lesson(s) overlap this unavailable period. They will remain scheduled and show as occupied.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Save anyway')),
                      ],
                    ));
            if (proceed != true) return;
          }
        }
        if (existing?.weekday != null) {
          await source.changeRecurringAvailability(
              id: existing!.id,
              fromDate: day,
              startMinute: result.start,
              endMinute: result.end,
              available: result.available,
              delete: false);
        } else {
          await source.saveAvailability(
            id: existing?.id,
            recurring: result.recurring,
            date: existing?.date ?? day,
            startMinute: result.start,
            endMinute: result.end,
            available: result.available,
          );
        }
      }
      if (mounted) setState(_loadAvailability);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save availability: $error')));
      }
    }
  }

  Future<void> _chooseRangeAction(DateTime day, int start, int end,
      List<AvailabilityPeriod> periods, List<Student> students) async {
    final action = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Block Time'),
                  onTap: () => Navigator.pop(context, true)),
              ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Availability'),
                  onTap: () => Navigator.pop(context, false)),
            ])));
    if (!mounted || action == null) return;
    if (action) {
      await _openTimeBlockDialog(day, start, end, students);
    } else {
      await _openPeriodDialog(day, start, end, true, periods, students);
    }
  }

  Future<void> _openTimeBlockDialog(
      DateTime day, int startMinute, int endMinute, List<Student> students,
      {TimeBlockOccurrence? occurrence, String? preset}) async {
    if (widget.api is! CalendarAvailabilityDataSource) return;
    final source = widget.api as CalendarAvailabilityDataSource;
    final initial = occurrence?.block ??
        TimeBlock(
          id: '',
          title: '',
          category: BlockCategory.other,
          start: DateTime.utc(day.year, day.month, day.day, startMinute ~/ 60,
              startMinute % 60),
          end: DateTime.utc(
              day.year, day.month, day.day, endMinute ~/ 60, endMinute % 60),
          allDay: startMinute == 0 && endMinute == 1440,
          repeat: BlockRepeat.never,
        );
    final result = await showDialog<TimeBlockResult>(
        context: context,
        builder: (context) => TimeBlockDialog(
            initial: initial, occurrence: occurrence, preset: preset));
    if (result == null || !mounted) return;
    try {
      if (result.action == TimeBlockAction.delete) {
        if (occurrence != null &&
            initial.repeat != BlockRepeat.never &&
            result.scope == TimeBlockScope.occurrence) {
          await source.changeTimeBlockOccurrence(initial.id, occurrence.date,
              cancelled: true);
        } else {
          await source.deleteTimeBlock(initial.id);
        }
      } else {
        final changed = result.block;
        final occurrenceOnly = occurrence != null &&
            initial.repeat != BlockRepeat.never &&
            result.scope == TimeBlockScope.occurrence;
        final candidate = occurrenceOnly
            ? TimeBlockOccurrence(
                changed, occurrence.date, changed.start, changed.end)
            : null;
        final events = _eventsForStudents(
            visibleStudentsForTeacher(students, widget.teacher));
        var conflicts = 0;
        for (final event in events) {
          if (event.course.status == 'CANCELED' || event.course.hour == null) {
            continue;
          }
          final overlaps = occurrenceOnly
              ? [candidate!]
              : changed.occurrences(event.start, event.start);
          for (final block in overlaps) {
            final lessonStart = DateTime.utc(
                event.start.year,
                event.start.month,
                event.start.day,
                event.start.hour,
                event.start.minute);
            final lessonEnd =
                lessonStart.add(Duration(minutes: event.durationMinutes));
            if (block.start.isBefore(lessonEnd) &&
                block.end.isAfter(lessonStart)) {
              conflicts++;
              break;
            }
          }
        }
        if (conflicts > 0) {
          final proceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Existing lessons overlap'),
                    content: Text(
                        '$conflicts scheduled lesson(s) overlap this block. '
                        'They will remain scheduled.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save anyway')),
                    ],
                  ));
          if (proceed != true) return;
        }
        if (occurrenceOnly) {
          await source.changeTimeBlockOccurrence(initial.id, occurrence.date,
              start: changed.start,
              end: changed.end,
              title: changed.title,
              category: changed.category,
              notes: changed.notes);
        } else {
          await source.saveTimeBlock(changed);
        }
      }
      if (mounted) setState(_loadAvailability);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save blocked time: $error')));
      }
    }
  }

  Future<void> _copyDay(DateTime sourceDay) async {
    if (widget.api is! CalendarAvailabilityDataSource) return;
    final source = widget.api as CalendarAvailabilityDataSource;
    final selected = <int>{};
    final weekdays = [1, 2, 3, 4, 5, 6, 7];
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title:
                      Text('Copy ${DateFormat.EEEE().format(sourceDay)} hours'),
                  content: SizedBox(
                      width: 300,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final weekday in weekdays)
                          if (weekday != sourceDay.weekday)
                            CheckboxListTile(
                              title: Text(DateFormat.EEEE().format(
                                  sourceDay.add(Duration(
                                      days: weekday - sourceDay.weekday)))),
                              value: selected.contains(weekday),
                              onChanged: (value) => update(() => value == true
                                  ? selected.add(weekday)
                                  : selected.remove(weekday)),
                            ),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Copy')),
                  ],
                )));
    if (confirmed != true) return;
    try {
      await source.copyAvailabilityDay(sourceDay, selected.toList());
      if (mounted) setState(_loadAvailability);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not copy hours: $error')));
      }
    }
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

class _PeriodDraft {
  const _PeriodDraft(this.recurring, this.available, this.start, this.end)
      : delete = false;
  const _PeriodDraft.delete()
      : recurring = false,
        available = false,
        start = 0,
        end = 0,
        delete = true;
  final bool recurring;
  final bool available;
  final int start;
  final int end;
  final bool delete;
}

class _AvailabilityDay extends StatefulWidget {
  const _AvailabilityDay({
    required this.day,
    required this.periods,
    required this.busy,
    required this.blocks,
    required this.events,
    required this.onSelect,
    required this.onBlockEdit,
    required this.onEdit,
    required this.onCopy,
  });
  final DateTime day;
  final List<AvailabilityPeriod> periods;
  final List<BusyPeriod> busy;
  final List<TimeBlock> blocks;
  final List<_LessonEvent> events;
  final void Function(DateTime, int, int) onSelect;
  final ValueChanged<TimeBlockOccurrence> onBlockEdit;
  final ValueChanged<AvailabilityPeriod> onEdit;
  final VoidCallback onCopy;

  @override
  State<_AvailabilityDay> createState() => _AvailabilityDayState();
}

class _AvailabilityDayState extends State<_AvailabilityDay> {
  int? _dragStart;
  int? _dragEnd;
  static const _rowHeight = 32.0;

  int _minuteFor(double dy) => ((dy / _rowHeight).floor().clamp(0, 47)) * 30;

  @override
  Widget build(BuildContext context) {
    const calculator = AvailabilityCalculator();
    final dayBlocks = [
      for (final block in widget.blocks)
        ...block.occurrences(widget.day, widget.day)
    ];
    final blockSlices = <TimeBlockOccurrence, BusyPeriod>{
      for (final block in dayBlocks)
        if (block.slice(widget.day) case final slice?) block: slice,
    };
    final segments = calculator.segmentsForDay(
        widget.day, widget.periods, [...widget.busy, ...blockSlices.values]);
    final dayPeriods = widget.periods
        .where((period) => period.appliesTo(widget.day))
        .toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return Container(
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: MaestroColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 72,
            child: Column(children: [
              Text(DateFormat('EEE d').format(widget.day).toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _isSameDay(widget.day, DateTime.now())
                          ? MaestroColors.primary
                          : MaestroColors.text)),
              TextButton(
                  onPressed: widget.onCopy,
                  child:
                      const Text('Copy hours', style: TextStyle(fontSize: 11))),
            ])),
        SizedBox(
            height: 84,
            child: SingleChildScrollView(
                child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final period in dayPeriods)
                  ActionChip(
                      onPressed: () => widget.onEdit(period),
                      label: Text(
                          '${period.available ? '✓' : '✕'} '
                          '${clockLabel(period.startMinute)}–'
                          '${clockLabel(period.endMinute)}',
                          style: const TextStyle(fontSize: 10)),
                      backgroundColor: period.date == null
                          ? period.available
                              ? const Color(0xFFE1F3E6)
                              : const Color(0xFFF5E3E3)
                          : const Color(0xFFFFEBD0)),
                for (final block in dayBlocks)
                  ActionChip(
                      onPressed: () => widget.onBlockEdit(block),
                      label: Text(block.displayTitle,
                          style: const TextStyle(fontSize: 10)),
                      backgroundColor: _blockColor(block.displayCategory)),
              ],
            ))),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final start = _minuteFor(details.localPosition.dy);
            final block = blockSlices.entries
                .where((entry) =>
                    entry.value.startMinute < start + 30 &&
                    entry.value.endMinute > start)
                .firstOrNull;
            if (block != null) {
              widget.onBlockEdit(block.key);
              return;
            }
            widget.onSelect(widget.day, start, start + 30);
          },
          onLongPressStart: (details) => setState(() {
            _dragStart = _minuteFor(details.localPosition.dy);
            _dragEnd = _dragStart;
          }),
          onLongPressMoveUpdate: (details) => setState(() {
            _dragEnd = _minuteFor(details.localPosition.dy);
          }),
          onLongPressEnd: (_) {
            final start = _dragStart;
            final end = _dragEnd;
            setState(() {
              _dragStart = null;
              _dragEnd = null;
            });
            if (start != null && end != null) {
              widget.onSelect(widget.day, start < end ? start : end,
                  (start > end ? start : end) + 30);
            }
          },
          child: Column(children: [
            for (var index = 0; index < 48; index++)
              Builder(builder: (context) {
                final minute = index * 30;
                final segment = segments.firstWhere((segment) =>
                    segment.startMinute <= minute &&
                    segment.endMinute > minute);
                final lesson = widget.events
                    .where((event) =>
                        _isSameDay(event.start, widget.day) &&
                        event.start.hour * 60 + event.start.minute <
                            minute + 30 &&
                        event.start.hour * 60 +
                                event.start.minute +
                                event.durationMinutes >
                            minute)
                    .firstOrNull;
                final selected = _dragStart != null &&
                    _dragEnd != null &&
                    minute >=
                        (_dragStart! < _dragEnd! ? _dragStart! : _dragEnd!) &&
                    minute <=
                        (_dragStart! > _dragEnd! ? _dragStart! : _dragEnd!);
                final block = blockSlices.entries
                    .where((entry) =>
                        entry.value.startMinute < minute + 30 &&
                        entry.value.endMinute > minute)
                    .firstOrNull;
                final explicitlyUnavailable = dayPeriods.any((period) =>
                    !period.available &&
                    period.startMinute < minute + 30 &&
                    period.endMinute > minute);
                final color = selected
                    ? const Color(0xFFC9D8FF)
                    : block != null
                        ? _blockColor(block.key.displayCategory)
                        : lesson != null
                            ? const Color(0xFFDDEBFF)
                            : explicitlyUnavailable && !segment.available
                                ? const Color(0xFFF5DADB)
                                : segment.available
                                    ? const Color(0xFFE1F3E6)
                                    : const Color(0xFFF4F5F6);
                return Container(
                    height: _rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: color,
                        border: const Border(
                            top: BorderSide(color: MaestroColors.border))),
                    child: Row(children: [
                      Text(clockLabel(minute),
                          style: const TextStyle(
                              color: MaestroColors.muted, fontSize: 10)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                              lesson?.studentName ??
                                  (block?.key.displayTitle ??
                                      (segment.occupied
                                          ? 'Occupied'
                                          : segment.available
                                              ? 'Available'
                                              : '')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700))),
                    ]));
              }),
          ]),
        ),
      ]),
    );
  }
}

Color _blockColor(BlockCategory category) => switch (category) {
      BlockCategory.sleep => const Color(0xFFE0E1E5),
      BlockCategory.vacation ||
      BlockCategory.personal =>
        const Color(0xFFFFE4C3),
      BlockCategory.breakTime || BlockCategory.other => const Color(0xFFF5DADB),
    };

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
      (index) => _addCalendarDays(_startOfWeek(selectedDate), index),
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
                      height: _eventHeight(event.durationMinutes),
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
  String get courseLabel => course.title.trim().isEmpty ||
          RegExp(r'^(Course \d+|First course)$', caseSensitive: false)
              .hasMatch(course.title.trim())
      ? 'Course $courseNumber'
      : course.title;
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

DateTime _addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

DateTime _startOfWeek(DateTime value) {
  final date = _dateOnly(value);
  return _addCalendarDays(date, DateTime.monday - date.weekday);
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

List<DateTime> _monthGridDays(DateTime selectedDate) {
  final monthStart = DateTime(selectedDate.year, selectedDate.month);
  final first = _startOfWeek(monthStart);
  return List.generate(42, (index) => _addCalendarDays(first, index));
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
  final end = _addCalendarDays(start, 6);
  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat.MMMM().format(start)} ${start.day} - ${end.day}, ${end.year}';
  }
  return '${DateFormat.MMMd().format(start)} - ${DateFormat.yMMMd().format(end)}';
}

StatusTone _statusTone(String status) {
  return switch (status.toUpperCase()) {
    'PRESENT' => StatusTone.success,
    'UPCOMING' || 'NOT SET' || 'SCHEDULED' => StatusTone.warning,
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
