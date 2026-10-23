import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/calendar_availability.dart';
import 'package:maestro_mobile/models/time_block.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/calendar_screen.dart';
import 'package:maestro_mobile/screens/time_block_dialog.dart';
import 'package:maestro_mobile/services/calendar_availability_data_source.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';

class _CalendarSource
    implements MaestroDataSource, CalendarAvailabilityDataSource {
  final requestedWeeks = <DateTime>[];
  final savedBlocks = <TimeBlock>[];
  final periods = <AvailabilityPeriod>[];
  final cancelledBlockDates = <DateTime>[];
  final copiedDays = <(DateTime, List<int>)>[];

  @override
  Future<List<Student>> fetchStudents() async => [];

  @override
  Future<List<AvailabilityPeriod>> fetchAvailability(
      DateTime weekStart, DateTime weekEnd) async {
    requestedWeeks.add(weekStart);
    return periods;
  }

  @override
  Future<List<TimeBlock>> fetchTimeBlocks(
          DateTime from, DateTime through) async =>
      savedBlocks;

  @override
  Future<void> saveTimeBlock(TimeBlock block) async => savedBlocks.add(block);

  @override
  Future<void> changeTimeBlockOccurrence(
      String blockId, DateTime occurrenceDate,
      {bool cancelled = false,
      DateTime? start,
      DateTime? end,
      String? title,
      BlockCategory? category,
      String? notes}) async {
    if (cancelled) cancelledBlockDates.add(occurrenceDate);
  }

  @override
  Future<void> copyAvailabilityDay(
      DateTime sourceDate, List<int> targetWeekdays) async {
    copiedDays.add((sourceDate, targetWeekdays));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Finder gridRow(DateTime day, int minute) =>
      find.byKey(ValueKey('availability-grid-${dayNumber(day)}-$minute'));

  void expectGridLabel(DateTime day, int minute, String label) {
    expect(
        find.descendant(of: gridRow(day, minute), matching: find.text(label)),
        findsOneWidget);
  }

  testWidgets('availability navigates Monday weeks and Today returns home',
      (tester) async {
    final source = _CalendarSource();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CalendarScreen(
      api: source,
      teacher: const Teacher(id: 1, name: 'Teacher'),
      onOpenStudent: (_) {},
      onOpenLesson: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Availability').first);
    await tester.pumpAndSettle();
    final initial = source.requestedWeeks.last;
    expect(initial.weekday, DateTime.monday);
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    final next = source.requestedWeeks.last;
    expect(next.weekday, DateTime.monday);
    expect(dayNumber(next) - dayNumber(initial), isNot(0));
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(source.requestedWeeks.last.weekday, DateTime.monday);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(dayNumber(source.requestedWeeks.last), dayNumber(initial));
  });

  testWidgets(
      'Calendar has two views and quick Sleep creates an overnight block',
      (tester) async {
    final source = _CalendarSource();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CalendarScreen(
      api: source,
      teacher: const Teacher(id: 1, name: 'Teacher'),
      onOpenStudent: (_) {},
      onOpenLesson: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Combined'), findsNothing);
    await tester.tap(find.text('Availability').first);
    await tester.pumpAndSettle();
    expect(find.text('+ Block Time'), findsOneWidget);
    await tester.tap(find.text('Sleep').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(source.savedBlocks, hasLength(1));
    final block = source.savedBlocks.single;
    expect(block.title, 'Sleep');
    expect(block.repeat, BlockRepeat.daily);
    expect(block.start.hour, 23);
    expect(block.end.hour, 7);
    expect(block.end.day, isNot(block.start.day));
  });

  testWidgets('Block Time form fits a mobile viewport', (tester) async {
    final source = _CalendarSource();
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CalendarScreen(
      api: source,
      teacher: const Teacher(id: 1, name: 'Teacher'),
      onOpenStudent: (_) {},
      onOpenLesson: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Availability').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Block Time'));
    await tester.pumpAndSettle();
    expect(find.text('Title or reason'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'recurring overnight Sleep appears only in timed grid rows and can be deleted there',
      (tester) async {
    final source = _CalendarSource();
    final today = DateTime.now();
    final monday = DateTime.utc(
        today.year, today.month, today.day - (today.weekday - DateTime.monday));
    final tuesday = monday.add(const Duration(days: 1));
    source.savedBlocks.add(TimeBlock(
      id: 'sleep-1',
      title: 'Sleep',
      category: BlockCategory.sleep,
      start: DateTime.utc(monday.year, monday.month, monday.day, 23),
      end: DateTime.utc(monday.year, monday.month, monday.day + 1, 7),
      allDay: false,
      repeat: BlockRepeat.daily,
    ));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CalendarScreen(
      api: source,
      teacher: const Teacher(id: 1, name: 'Teacher'),
      onOpenStudent: (_) {},
      onOpenLesson: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Availability').first);
    await tester.pumpAndSettle();

    // The only Sleep chip is the toolbar preset, not a day header duplicate.
    expect(find.widgetWithText(ActionChip, 'Sleep'), findsOneWidget);
    expect(find.text('Copy hours'), findsNWidgets(7));
    expectGridLabel(monday, 23 * 60, 'Sleep');
    expectGridLabel(monday, 23 * 60 + 30, 'Sleep');
    expectGridLabel(tuesday, 0, 'Sleep');
    expectGridLabel(tuesday, 6 * 60 + 30, 'Sleep');
    expectGridLabel(tuesday, 23 * 60, 'Sleep');
    expect(
        find.descendant(
            of: gridRow(tuesday, 7 * 60), matching: find.text('Sleep')),
        findsNothing);

    await tester.ensureVisible(gridRow(monday, 23 * 60));
    await tester.pumpAndSettle();
    await tester.tap(gridRow(monday, 23 * 60));
    await tester.pumpAndSettle();
    expect(find.byType(TimeBlockDialog), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete repeating block?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(source.cancelledBlockDates, hasLength(1));
    expect(dayNumber(source.cancelledBlockDates.single), dayNumber(monday));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable hours appear in the grid and Copy hours works',
      (tester) async {
    final source = _CalendarSource();
    final today = DateTime.now();
    final monday = DateTime.utc(
        today.year, today.month, today.day - (today.weekday - DateTime.monday));
    source.periods.add(const AvailabilityPeriod(
        id: 'work-1',
        weekday: DateTime.monday,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        available: false));
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CalendarScreen(
      api: source,
      teacher: const Teacher(id: 1, name: 'Teacher'),
      onOpenStudent: (_) {},
      onOpenLesson: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Availability').first);
    await tester.pumpAndSettle();
    expectGridLabel(monday, 9 * 60, 'Unavailable');
    expect(find.text('✕ 09:00–10:00'), findsNothing);
    await tester.ensureVisible(gridRow(monday, 9 * 60));
    await tester.pumpAndSettle();
    await tester.tap(gridRow(monday, 9 * 60));
    await tester.pumpAndSettle();
    expect(find.text('Edit calendar period'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Copy hours').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy hours').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tuesday').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Copy').last);
    await tester.pumpAndSettle();
    expect(source.copiedDays, hasLength(1));
    expect(dayNumber(source.copiedDays.single.$1), dayNumber(monday));
    expect(source.copiedDays.single.$2, [DateTime.tuesday]);
    expect(tester.takeException(), isNull);
  });
}
