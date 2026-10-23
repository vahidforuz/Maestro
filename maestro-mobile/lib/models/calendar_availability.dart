class AvailabilityPeriod {
  const AvailabilityPeriod({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    required this.available,
    this.weekday,
    this.date,
    this.effectiveFrom,
    this.effectiveUntil,
  });

  final String id;
  final int startMinute;
  final int endMinute;
  final bool available;
  final int? weekday;
  final DateTime? date;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;

  bool appliesTo(DateTime day) {
    final onlyDate = date;
    if (onlyDate != null) return sameCalendarDay(onlyDate, day);
    if (weekday != day.weekday) return false;
    final value = dayNumber(day);
    return (effectiveFrom == null || value >= dayNumber(effectiveFrom!)) &&
        (effectiveUntil == null || value <= dayNumber(effectiveUntil!));
  }
}

class BusyPeriod {
  const BusyPeriod(
      {required this.date, required this.startMinute, required this.endMinute});
  final DateTime date;
  final int startMinute;
  final int endMinute;
}

class AvailabilitySegment {
  const AvailabilitySegment(this.startMinute, this.endMinute, this.available,
      {this.exception = false, this.occupied = false});
  final int startMinute;
  final int endMinute;
  final bool available;
  final bool exception;
  final bool occupied;
}

int dayNumber(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
bool sameCalendarDay(DateTime a, DateTime b) => dayNumber(a) == dayNumber(b);

String clockLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

int? parseClock(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// Works with teacher-local wall-clock dates. Busy periods must already be
/// converted to that same timezone by their data source.
class AvailabilityCalculator {
  const AvailabilityCalculator();

  List<AvailabilitySegment> segmentsForDay(
    DateTime day,
    Iterable<AvailabilityPeriod> periods,
    Iterable<BusyPeriod> busy,
  ) {
    final matching = periods.where((period) => period.appliesTo(day)).toList();
    final matchingBusy =
        busy.where((period) => sameCalendarDay(period.date, day)).toList();
    final boundaries = <int>{0, 1440};
    for (final period in matching) {
      boundaries.add(period.startMinute);
      boundaries.add(period.endMinute);
    }
    for (final period in matchingBusy) {
      boundaries.add(period.startMinute.clamp(0, 1440));
      boundaries.add(period.endMinute.clamp(0, 1440));
    }
    final points = boundaries.toList()..sort();
    final segments = <AvailabilitySegment>[];
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (start == end) continue;
      final covering = matching.where(
          (period) => period.startMinute <= start && period.endMinute >= end);
      final exception = covering.any((period) => period.date != null);
      final weeklyAllowed =
          covering.any((period) => period.date == null && period.available);
      final weeklyBlocked =
          covering.any((period) => period.date == null && !period.available);
      final dateAllowed =
          covering.any((period) => period.date != null && period.available);
      final dateBlocked =
          covering.any((period) => period.date != null && !period.available);
      final occupied = matchingBusy.any(
          (period) => period.startMinute < end && period.endMinute > start);
      final available = (dateAllowed || (weeklyAllowed && !weeklyBlocked)) &&
          !dateBlocked &&
          !occupied;
      if (segments.isNotEmpty) {
        final previous = segments.last;
        if (previous.endMinute == start &&
            previous.available == available &&
            previous.exception == exception &&
            previous.occupied == occupied) {
          segments[segments.length - 1] = AvailabilitySegment(
              previous.startMinute, end, available,
              exception: exception, occupied: occupied);
          continue;
        }
      }
      segments.add(AvailabilitySegment(start, end, available,
          exception: exception, occupied: occupied));
    }
    return segments;
  }

  List<int> slotStarts(DateTime day, int durationMinutes,
      Iterable<AvailabilityPeriod> periods, Iterable<BusyPeriod> busy,
      {int stepMinutes = 15}) {
    if (durationMinutes <= 0 || durationMinutes > 1440 || stepMinutes <= 0) {
      throw ArgumentError('Invalid slot duration or step');
    }
    final segments = segmentsForDay(day, periods, busy);
    final slots = <int>[];
    for (var start = 0; start + durationMinutes <= 1440; start += stepMinutes) {
      if (segments
          .where((segment) =>
              segment.startMinute < start + durationMinutes &&
              segment.endMinute > start)
          .every((segment) => segment.available)) {
        slots.add(start);
      }
    }
    return slots;
  }

  bool conflictsWithBusy(
          DateTime day, int start, int end, Iterable<BusyPeriod> busy) =>
      busy.any((period) =>
          sameCalendarDay(period.date, day) &&
          period.startMinute < end &&
          period.endMinute > start);
}
