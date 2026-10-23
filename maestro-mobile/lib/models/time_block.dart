import 'calendar_availability.dart';

enum BlockRepeat { never, daily, weekly, custom }

enum BlockCategory { sleep, vacation, breakTime, personal, other }

class TimeBlockException {
  const TimeBlockException(
      {required this.date,
      this.cancelled = false,
      this.start,
      this.end,
      this.title,
      this.category,
      this.notes});
  final DateTime date;
  final bool cancelled;
  final DateTime? start;
  final DateTime? end;
  final String? title;
  final BlockCategory? category;
  final String? notes;
}

class TimeBlock {
  const TimeBlock(
      {required this.id,
      required this.title,
      required this.category,
      required this.start,
      required this.end,
      required this.allDay,
      required this.repeat,
      this.weekdays = const [],
      this.repeatUntil,
      this.notes,
      this.exceptions = const []});
  final String id;
  final String title;
  final BlockCategory category;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final BlockRepeat repeat;
  final List<int> weekdays;
  final DateTime? repeatUntil;
  final String? notes;
  final List<TimeBlockException> exceptions;

  bool occursOn(DateTime date) {
    if (dayNumber(date) < dayNumber(start) ||
        (repeatUntil != null && dayNumber(date) > dayNumber(repeatUntil!))) {
      return false;
    }
    return switch (repeat) {
      BlockRepeat.never => sameCalendarDay(date, start),
      BlockRepeat.daily => true,
      BlockRepeat.weekly => date.weekday == start.weekday,
      BlockRepeat.custom => weekdays.contains(date.weekday),
    };
  }

  Iterable<TimeBlockOccurrence> occurrences(
      DateTime from, DateTime through) sync* {
    // Start before the visible range so overnight and multi-day blocks appear.
    final span = DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    var date = DateTime.utc(from.year, from.month, from.day - span - 1);
    final last = DateTime.utc(through.year, through.month, through.day);
    final windowStart = DateTime.utc(from.year, from.month, from.day);
    final windowEnd =
        DateTime.utc(through.year, through.month, through.day + 1);
    final yielded = <int>{};
    while (dayNumber(date) <= dayNumber(last)) {
      if (occursOn(date)) {
        final exception =
            exceptions.where((e) => sameCalendarDay(e.date, date)).firstOrNull;
        if (exception?.cancelled != true) {
          final occurrenceStart = exception?.start ??
              DateTime.utc(
                  date.year, date.month, date.day, start.hour, start.minute);
          final occurrenceEnd = exception?.end ??
              DateTime.utc(
                  date.year, date.month, date.day + span, end.hour, end.minute);
          if (occurrenceEnd.isAfter(windowStart) &&
              occurrenceStart.isBefore(windowEnd)) {
            yielded.add(dayNumber(date));
            yield TimeBlockOccurrence(
                this, date, occurrenceStart, occurrenceEnd,
                title: exception?.title,
                category: exception?.category,
                notes: exception?.notes);
          }
        }
      }
      date = DateTime.utc(date.year, date.month, date.day + 1);
    }
    for (final exception in exceptions) {
      if (exception.cancelled ||
          exception.start == null ||
          exception.end == null ||
          yielded.contains(dayNumber(exception.date)) ||
          !exception.end!.isAfter(windowStart) ||
          !exception.start!.isBefore(windowEnd)) {
        continue;
      }
      yield TimeBlockOccurrence(
          this, exception.date, exception.start!, exception.end!,
          title: exception.title,
          category: exception.category,
          notes: exception.notes);
    }
  }
}

class TimeBlockOccurrence {
  const TimeBlockOccurrence(this.block, this.date, this.start, this.end,
      {this.title, this.category, this.notes});
  final TimeBlock block;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final String? title;
  final BlockCategory? category;
  final String? notes;
  String get displayTitle => title ?? block.title;
  BlockCategory get displayCategory => category ?? block.category;

  BusyPeriod? slice(DateTime day) {
    final from = DateTime.utc(day.year, day.month, day.day);
    final through = DateTime.utc(day.year, day.month, day.day + 1);
    if (!start.isBefore(through) || !end.isAfter(from)) return null;
    final clippedStart = start.isAfter(from) ? start : from;
    final clippedEnd = end.isBefore(through) ? end : through;
    return BusyPeriod(
        date: day,
        startMinute: clippedStart.hour * 60 + clippedStart.minute,
        endMinute: clippedEnd == through
            ? 1440
            : clippedEnd.hour * 60 + clippedEnd.minute);
  }
}
