import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/widgets/maestro_shell.dart';

void main() {
  for (final width in [420.0, 800.0, 1280.0]) {
    testWidgets('shared navigation and More work at $width px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0;
      var secondaryOpened = false;
      double? contentWidth;
      await tester.pumpWidget(MaterialApp(
          home: StatefulBuilder(
        builder: (context, update) => MaestroShell(
          title: 'Maestro',
          userName: 'Ada Teacher',
          selectedIndex: selected,
          unreadCount: 3,
          body: LayoutBuilder(builder: (context, box) {
            contentWidth = box.maxWidth;
            return const Center(child: Text('Body'));
          }),
          shortcuts: [
            MaestroShortcut(
                'Payments',
                Icons.payments_outlined,
                const Color(0xFF10B981),
                () => update(() => secondaryOpened = true),
                selected: secondaryOpened),
            MaestroShortcut('Availability', Icons.event_available_outlined,
                const Color(0xFFF59E0B), () {}),
            MaestroShortcut('Pieces / Projects', Icons.music_note_outlined,
                const Color(0xFF8B5CF6), () {}),
          ],
          onProfile: () {},
          onSettings: () {},
          onSignOut: () {},
          destinations: [
            for (final (index, label, icon) in [
              (0, 'Home', Icons.home_outlined),
              (1, 'Students', Icons.people_outline),
              (2, 'Calendar', Icons.calendar_month_outlined),
              (3, 'Messages', Icons.chat_bubble_outline),
            ])
              MaestroDestination(
                  label, icon, () => update(() => selected = index),
                  badge: index == 3 ? 3 : 0),
          ],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Ada Teacher'), findsNothing);
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      if (width < 600) {
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byKey(const ValueKey('shortcut-Payments')), findsNothing);
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            1);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Payments'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
        await tester.pumpAndSettle();
        expect(secondaryOpened, isTrue);
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            4);
        await tester.tap(find.text('More'));
      } else {
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.scrollable, isTrue);
        expect(rail.destinations.length, 8);
        expect(
            contentWidth,
            closeTo(
                width - tester.getSize(find.byType(NavigationRail)).width - 1,
                1));
        expect([
          for (final destination in rail.destinations)
            (destination.label as Text).data,
        ], [
          'Home',
          'Students',
          'Calendar',
          'Messages',
          'Payments',
          'Availability',
          'Pieces / Projects',
          'More'
        ]);
        expect(rail.selectedIndex, 1);
        await tester.tap(find.byKey(const ValueKey('shortcut-Payments')));
        await tester.pumpAndSettle();
        expect(secondaryOpened, isTrue);
        expect(
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .selectedIndex,
            4);
        await tester.tap(find.text('More'));
      }
      await tester.pumpAndSettle();
      for (final label in ['My Profile', 'Settings', 'Help', 'Sign Out']) {
        expect(find.widgetWithText(ListTile, label), findsOneWidget);
      }
      for (final label in ['Payments', 'Availability', 'Pieces / Projects']) {
        expect(find.widgetWithText(ListTile, label),
            width < 600 ? findsOneWidget : findsNothing);
      }
    });
  }

  testWidgets('bottom navigation stops its transition for reduced motion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaestroShell(
          title: 'Maestro',
          userName: 'Ada',
          selectedIndex: 0,
          body: const SizedBox.expand(),
          onProfile: () {},
          onSettings: () {},
          onSignOut: () {},
          destinations: [
            for (final label in ['Home', 'Students', 'Calendar', 'Messages'])
              MaestroDestination(label, Icons.circle_outlined, () {}),
          ],
        ),
      ),
    ));
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .animationDuration,
        Duration.zero);
  });

  testWidgets('the eight-item rail scrolls on a short tablet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MaestroShell(
      title: 'Maestro',
      userName: 'Ada',
      selectedIndex: 0,
      body: const SizedBox.expand(),
      onProfile: () {},
      onSettings: () {},
      onSignOut: () {},
      destinations: [
        for (final label in ['Home', 'Students', 'Calendar', 'Messages'])
          MaestroDestination(label, Icons.circle_outlined, () {}),
      ],
      shortcuts: [
        for (final label in ['Payments', 'Availability', 'Pieces / Projects'])
          MaestroShortcut(
              label, Icons.music_note_outlined, const Color(0xFF8B5CF6), () {}),
      ],
    )));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).scrollable,
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
