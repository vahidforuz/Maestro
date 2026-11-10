import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/widgets/maestro_shell.dart';

void main() {
  for (final width in [420.0, 1280.0]) {
    testWidgets('shared navigation and More work at $width px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0;
      var secondaryOpened = false;
      await tester.pumpWidget(MaterialApp(
          home: StatefulBuilder(
        builder: (context, update) => MaestroShell(
          title: 'Maestro',
          userName: 'Ada Teacher',
          selectedIndex: selected,
          unreadCount: 3,
          body: const Center(child: Text('Body')),
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
          more: [
            MaestroDestination('Payments', Icons.payments_outlined,
                () => secondaryOpened = true)
          ],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Ada Teacher'), findsNothing);
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      if (width < 600) {
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            1);
        await tester.tap(find.text('More'));
      } else {
        expect(
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .selectedIndex,
            1);
        await tester.tap(find.byTooltip('More'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Payments'));
      await tester.pumpAndSettle();
      expect(secondaryOpened, isTrue);
    });
  }
}
