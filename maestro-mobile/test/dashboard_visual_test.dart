import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/theme/maestro_theme.dart';
import 'package:maestro_mobile/widgets/dashboard_layout.dart';
import 'package:maestro_mobile/widgets/maestro_card.dart';

void main() {
  const stats = [
    DashboardStat('Students', '12', Icons.people_outline,
        accent: MaestroAccents.blue),
    DashboardStat('Lessons', '8', Icons.menu_book_outlined,
        accent: MaestroAccents.violet),
    DashboardStat('Payments', '4', Icons.payments_outlined,
        accent: MaestroAccents.green),
    DashboardStat('Progress', '75%', Icons.trending_up,
        accent: MaestroAccents.cyan),
  ];
  final actions = [
    DashboardAction('Students', Icons.people_outline, () {},
        accent: MaestroAccents.blue),
    DashboardAction('Lessons', Icons.menu_book_outlined, () {},
        accent: MaestroAccents.violet),
    DashboardAction('Payments', Icons.payments_outlined, () {},
        accent: MaestroAccents.green),
    DashboardAction('Calendar', Icons.calendar_month_outlined, () {},
        accent: MaestroAccents.orange),
    DashboardAction('Messages', Icons.chat_bubble_outline, () {},
        accent: MaestroAccents.pink),
    const DashboardAction('Progress', Icons.trending_up, null,
        accent: MaestroAccents.cyan),
  ];

  for (final theme in [MaestroTheme.light(), MaestroTheme.dark()]) {
    testWidgets(
        'dashboard uses shared palette and 3x2 mobile actions in ${theme.brightness}',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: DashboardLayout(
          greeting: 'Welcome, Aria',
          stats: stats,
          actions: actions,
          sections: const [MaestroCard(child: Text('Next lesson'))],
        )),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardHero), findsOneWidget);
      expect(find.byType(DashboardStatCard), findsNWidgets(4));
      expect(find.byType(DashboardActionTile), findsNWidgets(6));
      expect(tester.takeException(), isNull);

      final tiles = find.byType(DashboardActionTile);
      expect(
          tester.getTopLeft(tiles.at(0)).dy, tester.getTopLeft(tiles.at(2)).dy);
      expect(tester.getTopLeft(tiles.at(3)).dy,
          greaterThan(tester.getTopLeft(tiles.at(0)).dy));
      expect(
          tester.widget<DashboardActionTile>(tiles.at(5)).action.onTap, isNull);
    });
  }
}
