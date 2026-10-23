import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/calendar_availability.dart';

void main() {
  const calculator = AvailabilityCalculator();
  final monday = DateTime(2026, 10, 26);

  test('recurring periods apply on the correct weekday and effective dates',
      () {
    final rules = [
      AvailabilityPeriod(
          id: 'work',
          weekday: 1,
          startMinute: 540,
          endMinute: 1020,
          available: true,
          effectiveFrom: monday),
    ];
    expect(calculator.slotStarts(monday, 60, rules, []), contains(540));
    expect(
        calculator.slotStarts(DateTime(2026, 10, 27), 60, rules, []), isEmpty);
    expect(
        calculator.slotStarts(DateTime(2026, 10, 19), 60, rules, []), isEmpty);
    expect(calculator.slotStarts(DateTime(2026, 11, 2), 60, rules, []),
        contains(540));
  });

  test('holidays block a whole day; special availability adds a window', () {
    final rules = [
      AvailabilityPeriod(
          id: 'work',
          weekday: 1,
          startMinute: 540,
          endMinute: 1020,
          available: true,
          effectiveFrom: monday),
      AvailabilityPeriod(
          id: 'holiday',
          date: monday,
          startMinute: 0,
          endMinute: 1440,
          available: false),
      AvailabilityPeriod(
          id: 'special',
          date: DateTime(2026, 10, 27),
          startMinute: 600,
          endMinute: 720,
          available: true),
    ];
    expect(calculator.slotStarts(monday, 30, rules, []), isEmpty);
    expect(calculator.slotStarts(DateTime(2026, 10, 27), 60, rules, []),
        [600, 615, 630, 645, 660]);
  });

  test('occupied lesson time removes 30, 45, and 60 minute slots', () {
    final rules = [
      AvailabilityPeriod(
          id: 'work',
          weekday: 1,
          startMinute: 540,
          endMinute: 720,
          available: true,
          effectiveFrom: monday)
    ];
    final busy = [BusyPeriod(date: monday, startMinute: 600, endMinute: 645)];
    expect(calculator.slotStarts(monday, 30, rules, busy),
        containsAll([540, 555, 645, 660, 675, 690]));
    expect(
        calculator.slotStarts(monday, 45, rules, busy), isNot(contains(570)));
    expect(
        calculator.slotStarts(monday, 60, rules, busy), isNot(contains(585)));
    expect(calculator.conflictsWithBusy(monday, 585, 615, busy), isTrue);
    expect(calculator.conflictsWithBusy(monday, 645, 675, busy), isFalse);
  });

  test('unavailable exceptions override available exceptions', () {
    final periods = [
      AvailabilityPeriod(
          id: 'extra',
          date: monday,
          startMinute: 540,
          endMinute: 720,
          available: true),
      AvailabilityPeriod(
          id: 'appointment',
          date: monday,
          startMinute: 600,
          endMinute: 660,
          available: false),
    ];
    final slots = calculator.slotStarts(monday, 30, periods, []);
    expect(slots, contains(570));
    expect(slots, isNot(contains(600)));
    expect(slots, contains(660));
  });

  test('a slot may span adjacent available periods with different sources', () {
    final periods = [
      AvailabilityPeriod(
          id: 'work',
          weekday: 1,
          startMinute: 540,
          endMinute: 600,
          available: true,
          effectiveFrom: monday),
      AvailabilityPeriod(
          id: 'extra',
          date: monday,
          startMinute: 600,
          endMinute: 660,
          available: true),
    ];
    expect(calculator.slotStarts(monday, 60, periods, []), contains(570));
  });

  test('special availability overrides a weekly closure for that date', () {
    final periods = [
      AvailabilityPeriod(
          id: 'closed',
          weekday: 1,
          startMinute: 0,
          endMinute: 1440,
          available: false,
          effectiveFrom: monday),
      AvailabilityPeriod(
          id: 'special',
          date: monday,
          startMinute: 600,
          endMinute: 720,
          available: true),
    ];
    expect(calculator.slotStarts(monday, 60, periods, []), contains(600));
    expect(
        calculator.slotStarts(DateTime(2026, 11, 2), 60, periods, []), isEmpty);
  });
}
