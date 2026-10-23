import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/models/time_block.dart';
import 'package:maestro_mobile/screens/time_block_dialog.dart';

void main() {
  final series = TimeBlock(
      id: 'series',
      title: 'Lunch',
      category: BlockCategory.breakTime,
      start: DateTime.utc(2026, 10, 26, 12),
      end: DateTime.utc(2026, 10, 26, 13),
      allDay: false,
      repeat: BlockRepeat.daily);
  final occurrence = TimeBlockOccurrence(series, DateTime.utc(2026, 11, 2),
      DateTime.utc(2026, 11, 2, 12), DateTime.utc(2026, 11, 2, 13));

  testWidgets('series edit keeps original recurrence start', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TimeBlockResult? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showDialog<TimeBlockResult>(
            context: context,
            builder: (context) =>
                TimeBlockDialog(initial: series, occurrence: occurrence)),
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This occurrence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entire series').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result?.scope, TimeBlockScope.series);
    expect(result?.block.start.day, 26);
    expect(result?.block.start.month, 10);
  });

  testWidgets('deleting a recurring series requires confirmation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TimeBlockResult? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showDialog<TimeBlockResult>(
            context: context,
            builder: (context) =>
                TimeBlockDialog(initial: series, occurrence: occurrence)),
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This occurrence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entire series').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete repeating block?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(result?.action, TimeBlockAction.delete);
    expect(result?.scope, TimeBlockScope.series);
  });
}
