import 'dart:convert';

import 'package:file_selector/file_selector.dart' show getSaveLocation;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/calendar_availability.dart';
import '../models/time_block.dart';
import '../services/calendar_availability_data_source.dart';
import '../services/ics_export.dart';

class CalendarExportLesson {
  const CalendarExportLesson(
      {required this.id,
      required this.date,
      required this.startMinute,
      required this.durationMinutes,
      required this.teacherLabel});
  final int id;
  final DateTime date;
  final int startMinute;
  final int durationMinutes;
  final String teacherLabel;
}

class ExportCalendarDialog extends StatefulWidget {
  const ExportCalendarDialog(
      {super.key,
      required this.source,
      required this.teacherId,
      required this.timezone,
      required this.lessons});
  final CalendarAvailabilityDataSource source;
  final int teacherId;
  final String timezone;
  final List<CalendarExportLesson> lessons;

  @override
  State<ExportCalendarDialog> createState() => _ExportCalendarDialogState();
}

class _ExportCalendarDialogState extends State<ExportCalendarDialog> {
  bool _availability = true;
  late DateTime _from = _date(DateTime.now());
  late DateTime _until = _addDays(_from, 28);
  late final Set<int> _selected =
      widget.lessons.map((lesson) => lesson.id).toSet();
  bool _working = false;
  String? _error;

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime _addDays(DateTime value, int days) =>
      DateTime(value.year, value.month, value.day + days);

  Future<void> _chooseRange() async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: _from, end: _until));
    if (range != null) {
      setState(() {
        _from = range.start;
        _until = range.end;
      });
    }
  }

  Future<void> _export() async {
    final days = DateTime.utc(_until.year, _until.month, _until.day)
            .difference(DateTime.utc(_from.year, _from.month, _from.day))
            .inDays +
        1;
    if (days > 84) {
      setState(() => _error = 'Choose a range of at most 84 days.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final candidates = <_ExportCandidate>[];
      if (_availability) {
        final monday = _addDays(_from, 1 - _from.weekday);
        final weeks = <DateTime>[];
        for (var day = monday;
            dayNumber(day) <= dayNumber(_until);
            day = _addDays(day, 7)) {
          weeks.add(day);
        }
        final pages = await Future.wait([
          for (final week in weeks)
            widget.source.fetchAvailability(week, _addDays(week, 6))
        ]);
        final allPeriods = <String, AvailabilityPeriod>{
          for (final page in pages)
            for (final period in page) period.id: period,
        }.values.toList();
        final blockPages = await Future.wait([
          for (final week in weeks)
            widget.source.fetchTimeBlocks(week, _addDays(week, 6))
        ]);
        final blocks = <String, TimeBlock>{
          for (final page in blockPages)
            for (final block in page) block.id: block,
        }.values.toList();
        final busy = [
          for (final lesson in widget.lessons)
            BusyPeriod(
                date: lesson.date,
                startMinute: lesson.startMinute,
                endMinute: lesson.startMinute + lesson.durationMinutes)
        ];
        const calculator = AvailabilityCalculator();
        for (var day = _from;
            dayNumber(day) <= dayNumber(_until);
            day = _addDays(day, 1)) {
          final dayBlocks = [
            for (final block in blocks) ...block.occurrences(day, day)
          ];
          final blockBusy = [
            for (final block in dayBlocks)
              if (block.slice(day) case final slice?) slice,
          ];
          for (final segment in calculator
              .segmentsForDay(day, allPeriods, [...busy, ...blockBusy])) {
            if (!segment.available) continue;
            candidates.add(_ExportCandidate(
                'available-${widget.teacherId}-${DateFormat('yyyyMMdd').format(day)}-'
                '${segment.startMinute}-${segment.endMinute}',
                CalendarLocalRange(day, segment.startMinute, segment.endMinute),
                true));
          }
          for (final block in dayBlocks) {
            final slice = block.slice(day);
            if (slice == null) continue;
            candidates.add(_ExportCandidate(
                'blocked-${widget.teacherId}-${block.block.id}-'
                '${DateFormat('yyyyMMdd').format(block.date)}-'
                '${DateFormat('yyyyMMdd').format(day)}',
                CalendarLocalRange(day, slice.startMinute, slice.endMinute),
                false,
                summary: 'Blocked'));
          }
        }
      } else {
        for (final lesson in widget.lessons) {
          if (!_selected.contains(lesson.id) ||
              dayNumber(lesson.date) < dayNumber(_from) ||
              dayNumber(lesson.date) > dayNumber(_until)) {
            continue;
          }
          candidates.add(_ExportCandidate(
              'lesson-${widget.teacherId}-${lesson.id}',
              CalendarLocalRange(lesson.date, lesson.startMinute,
                  lesson.startMinute + lesson.durationMinutes),
              false));
        }
      }
      if (candidates.isEmpty) throw StateError('No events in this date range.');
      if (candidates.length > 1000) {
        throw StateError('Too many events; choose a shorter range.');
      }
      final converted = await widget.source.convertCalendarRanges(
          [for (final candidate in candidates) candidate.range]);
      if (converted.length != candidates.length) {
        throw StateError('Could not convert every calendar event.');
      }
      final ics = buildIcsCalendar([
        for (var index = 0; index < candidates.length; index++)
          IcsEvent(
              uid: candidates[index].uid,
              startUtc: converted[index].start,
              endUtc: converted[index].end,
              summary: candidates[index].summary,
              transparent: candidates[index].available),
      ]);
      if (!mounted) return;
      final filename =
          _availability ? 'maestro-availability.ics' : 'maestro-lessons.ics';
      final file = XFile.fromData(utf8.encode(ics),
          mimeType: 'text/calendar', name: filename);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final location = await getSaveLocation(suggestedName: filename);
        if (location != null) await file.saveTo(location.path);
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [file],
        fileNameOverrides: [filename],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleLessons = widget.lessons
        .where((lesson) =>
            dayNumber(lesson.date) >= dayNumber(_from) &&
            dayNumber(lesson.date) <= dayNumber(_until))
        .toList();
    return AlertDialog(
      title: const Text('Export Calendar'),
      content: SizedBox(
        width: 470,
        height: 430,
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Times are exported in UTC from ${widget.timezone}. '
                'Student details are excluded.'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
                selected: {_availability},
                onSelectionChanged: (value) =>
                    setState(() => _availability = value.first),
                segments: const [
                  ButtonSegment(value: true, label: Text('Availability')),
                  ButtonSegment(value: false, label: Text('Lessons')),
                ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _chooseRange,
                icon: const Icon(Icons.date_range),
                label: Text('${DateFormat.yMMMd().format(_from)} – '
                    '${DateFormat.yMMMd().format(_until)}')),
            if (!_availability) ...[
              const SizedBox(height: 12),
              const Text('Select lessons',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              for (final lesson in visibleLessons)
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${DateFormat.yMMMd().format(lesson.date)} '
                        '${clockLabel(lesson.startMinute)} · ${lesson.teacherLabel}'),
                    value: _selected.contains(lesson.id),
                    onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(lesson.id);
                          } else {
                            _selected.remove(lesson.id);
                          }
                        })),
              if (visibleLessons.isEmpty)
                const Text('No lessons in this range.'),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
          ],
        )),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton.icon(
            onPressed: _working ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: Text(_working ? 'Preparing…' : 'Download or Share .ics')),
      ],
    );
  }
}

class _ExportCandidate {
  const _ExportCandidate(this.uid, this.range, this.available,
      {String? summary})
      : summary = summary ?? (available ? 'Available' : 'Lesson');
  final String uid;
  final CalendarLocalRange range;
  final bool available;
  final String summary;
}
