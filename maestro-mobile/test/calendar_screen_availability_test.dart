import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/calendar_availability.dart';
import 'package:maestro_mobile/models/time_block.dart';
import 'package:maestro_mobile/models/student.dart';
import 'package:maestro_mobile/models/teacher.dart';
import 'package:maestro_mobile/screens/calendar_screen.dart';
import 'package:maestro_mobile/services/calendar_availability_data_source.dart';
import 'package:maestro_mobile/services/maestro_data_source.dart';

class _CalendarSource
    implements MaestroDataSource, CalendarAvailabilityDataSource {
  final requestedWeeks = <DateTime>[];
  final savedBlocks = <TimeBlock>[];

  @override
  Future<List<Student>> fetchStudents() async => [];

  @override
  Future<List<AvailabilityPeriod>> fetchAvailability(
      DateTime weekStart, DateTime weekEnd) async {
    requestedWeeks.add(weekStart);
    return [];
  }

  @override
  Future<List<TimeBlock>> fetchTimeBlocks(
          DateTime from, DateTime through) async =>
      savedBlocks;

  @override
  Future<void> saveTimeBlock(TimeBlock block) async => savedBlocks.add(block);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
}
