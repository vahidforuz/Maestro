import 'package:flutter/material.dart';

import 'maestro_card.dart';

class DashboardStat {
  const DashboardStat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class DashboardAction {
  const DashboardAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _block(context, 220, 28),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: _block(context, double.infinity, 110)),
            const SizedBox(width: 12),
            Expanded(child: _block(context, double.infinity, 110)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _block(context, double.infinity, 110)),
            const SizedBox(width: 12),
            Expanded(child: _block(context, double.infinity, 110)),
          ]),
          const SizedBox(height: 24),
          _block(context, double.infinity, 120),
        ]),
      );

  static Widget _block(BuildContext context, double width, double height) =>
      Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14)));
}

class DashboardLayout extends StatelessWidget {
  const DashboardLayout(
      {super.key,
      required this.greeting,
      required this.stats,
      required this.actions,
      required this.sections,
      this.top});

  final String greeting;
  final List<DashboardStat> stats;
  final List<DashboardAction> actions;
  final List<Widget> sections;
  final Widget? top;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final statColumns = width < 600 ? 2 : 4;
        final actionColumns = width < 600
            ? 3
            : width < 900
                ? 3
                : 6;
        final sectionColumns = width < 800
            ? 1
            : width < 1200
                ? 2
                : 3;
        return Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: ListView(
                  key: const PageStorageKey('dashboard-scroll'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(greeting,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (top != null) ...[const SizedBox(height: 16), top!],
                    const SizedBox(height: 18),
                    _grid(
                        context,
                        stats.length,
                        statColumns,
                        150,
                        (index) => MaestroCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Icon(stats[index].icon,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 8),
                                  Text(stats[index].value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  Text(stats[index].label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ]))),
                    const SizedBox(height: 22),
                    Text('Quick actions',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _grid(
                        context,
                        actions.length,
                        actionColumns,
                        130,
                        (index) => Tooltip(
                            message: actions[index].onTap == null
                                ? 'Not available yet'
                                : actions[index].label,
                            child: OutlinedButton(
                              onPressed: actions[index].onTap,
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(10)),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(actions[index].icon),
                                    const SizedBox(height: 6),
                                    Text(actions[index].label,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ]),
                            ))),
                    const SizedBox(height: 22),
                    _grid(context, sections.length, sectionColumns, null,
                        (index) => sections[index]),
                  ],
                )));
      });

  static Widget _grid(BuildContext context, int count, int columns,
      double? height, Widget Function(int) build) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 12.0;
      final itemWidth = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < count; i++)
          SizedBox(width: itemWidth, height: height, child: build(i)),
      ]);
    });
  }
}
