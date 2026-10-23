import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/calendar_availability.dart';
import 'package:maestro_mobile/models/time_block.dart';

void main() {
  TimeBlock block(
          {required DateTime start,
          required DateTime end,
          BlockRepeat repeat = BlockRepeat.never,
          bool allDay = false,
          List<int> weekdays = const [],
          DateTime? until,
          List<TimeBlockException> exceptions = const []}) =>
      TimeBlock(
          id: 'b1',
          title: 'Private appointment',
          category: BlockCategory.personal,
          start: start,
          end: end,
          allDay: allDay,
          repeat: repeat,
          weekdays: weekdays,
          repeatUntil: until,
          exceptions: exceptions);

  test('daily overnight sleep occupies both sides of midnight across DST', () {
    final sleep = block(
        start: DateTime.utc(2026, 3, 7, 23),
        end: DateTime.utc(2026, 3, 8, 7),
        repeat: BlockRepeat.daily);
    final sunday = DateTime.utc(2026, 3, 8);
    final slices = sleep
        .occurrences(sunday, sunday)
        .map((occurrence) => occurrence.slice(sunday)!)
        .toList();
    expect(
        slices.map((slice) => [slice.startMinute, slice.endMinute]),
        containsAll([
          [0, 420],
          [1380, 1440]
        ]));
    // These are teacher wall-clock ranges; DST conversion is done by Supabase.
    final monday = DateTime.utc(2026, 3, 9);
    expect(sleep.occurrences(monday, monday).length, 2);
  });

  test('multi-day vacation and all-day block cover every selected date', () {
    final vacation = block(
        start: DateTime.utc(2026, 10, 25),
        end: DateTime.utc(2026, 10, 31),
        allDay: true);
    for (var day = 25; day <= 30; day++) {
      final date = DateTime.utc(2026, 10, day);
      final slice = vacation.occurrences(date, date).single.slice(date)!;
      expect([slice.startMinute, slice.endMinute], [0, 1440]);
    }
    expect(
        vacation.occurrences(
            DateTime.utc(2026, 10, 31), DateTime.utc(2026, 10, 31)),
        isEmpty);
  });

  test('weekly and custom recurrences honor end date', () {
    final sunday = block(
        start: DateTime.utc(2026, 10, 25),
        end: DateTime.utc(2026, 10, 26),
        repeat: BlockRepeat.weekly,
        until: DateTime.utc(2026, 11, 8));
    expect(
        sunday.occurrences(
            DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 1)),
        hasLength(1));
    expect(
        sunday.occurrences(
            DateTime.utc(2026, 11, 15), DateTime.utc(2026, 11, 15)),
        isEmpty);
    final custom = block(
        start: DateTime.utc(2026, 10, 26, 12),
        end: DateTime.utc(2026, 10, 26, 13),
        repeat: BlockRepeat.custom,
        weekdays: [1, 3]);
    expect(
        custom.occurrences(
            DateTime.utc(2026, 10, 28), DateTime.utc(2026, 10, 28)),
        hasLength(1));
    expect(
        custom.occurrences(
            DateTime.utc(2026, 10, 29), DateTime.utc(2026, 10, 29)),
        isEmpty);
  });

  test('one occurrence can be cancelled or moved without changing series', () {
    final recurring = block(
        start: DateTime.utc(2026, 10, 26, 12),
        end: DateTime.utc(2026, 10, 26, 13),
        repeat: BlockRepeat.daily,
        exceptions: [
          TimeBlockException(date: DateTime.utc(2026, 10, 27), cancelled: true),
          TimeBlockException(
              date: DateTime.utc(2026, 10, 28),
              start: DateTime.utc(2026, 10, 28, 14),
              end: DateTime.utc(2026, 10, 28, 16),
              title: 'Moved'),
        ]);
    expect(
        recurring.occurrences(
            DateTime.utc(2026, 10, 27), DateTime.utc(2026, 10, 27)),
        isEmpty);
    final moved = recurring
        .occurrences(DateTime.utc(2026, 10, 28), DateTime.utc(2026, 10, 28))
        .single;
    expect(moved.displayTitle, 'Moved');
    expect(moved.slice(DateTime.utc(2026, 10, 28))!.startMinute, 840);
    expect(
        recurring
            .occurrences(DateTime.utc(2026, 10, 29), DateTime.utc(2026, 10, 29))
            .single
            .start
            .hour,
        12);
  });

  test('blocked time and existing lesson both subtract from working slots', () {
    final day = DateTime.utc(2026, 10, 26);
    final work = [
      AvailabilityPeriod(
          id: 'work',
          weekday: 1,
          startMinute: 540,
          endMinute: 1020,
          available: true,
          effectiveFrom: day)
    ];
    final appointment = block(
        start: DateTime.utc(2026, 10, 26, 12),
        end: DateTime.utc(2026, 10, 26, 13));
    final busy = [
      BusyPeriod(date: day, startMinute: 600, endMinute: 660),
      appointment.occurrences(day, day).single.slice(day)!
    ];
    const calculator = AvailabilityCalculator();
    final slots = calculator.slotStarts(day, 60, work, busy);
    expect(slots, isNot(contains(600)));
    expect(slots, isNot(contains(720)));
    expect(slots, contains(780));
  });
}
