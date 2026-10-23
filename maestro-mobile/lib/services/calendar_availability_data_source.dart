import '../models/calendar_availability.dart';
import '../models/time_block.dart';

class AvailabilityShareLink {
  const AvailabilityShareLink({
    required this.id,
    required this.createdAt,
    this.expiresAt,
    this.rangeFrom,
    this.rangeUntil,
    this.revokedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? rangeFrom;
  final DateTime? rangeUntil;
  final DateTime? revokedAt;

  bool get active =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

class CreatedAvailabilityShareLink {
  const CreatedAvailabilityShareLink(this.id, this.token);
  final String id;
  final String token;
}

class CalendarLocalRange {
  const CalendarLocalRange(this.date, this.startMinute, this.endMinute);
  final DateTime date;
  final int startMinute;
  final int endMinute;
}

class CalendarUtcRange {
  const CalendarUtcRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

abstract interface class CalendarAvailabilityDataSource {
  Future<List<TimeBlock>> fetchTimeBlocks(DateTime from, DateTime through);
  Future<void> saveTimeBlock(TimeBlock block);
  Future<void> deleteTimeBlock(String id);
  Future<void> changeTimeBlockOccurrence(
      String blockId, DateTime occurrenceDate,
      {bool cancelled = false,
      DateTime? start,
      DateTime? end,
      String? title,
      BlockCategory? category,
      String? notes});

  Future<List<AvailabilityPeriod>> fetchAvailability(
      DateTime weekStart, DateTime weekEnd);

  Future<void> saveAvailability({
    String? id,
    required bool recurring,
    required DateTime date,
    required int startMinute,
    required int endMinute,
    required bool available,
    DateTime? effectiveUntil,
  });

  Future<void> deleteAvailability(String id, {required bool recurring});

  Future<void> changeRecurringAvailability({
    required String id,
    required DateTime fromDate,
    required int startMinute,
    required int endMinute,
    required bool available,
    required bool delete,
  });

  Future<void> copyAvailabilityDay(
      DateTime sourceDate, List<int> targetWeekdays);

  Future<List<AvailabilityShareLink>> fetchAvailabilityShareLinks();
  Future<CreatedAvailabilityShareLink> createAvailabilityShareLink(
      {DateTime? expiresAt, DateTime? rangeFrom, DateTime? rangeUntil});
  Future<void> revokeAvailabilityShareLink(String id);

  Future<List<CalendarUtcRange>> convertCalendarRanges(
      List<CalendarLocalRange> ranges);
}
