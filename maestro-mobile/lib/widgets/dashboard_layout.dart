import 'package:flutter/material.dart';

import '../theme/maestro_theme.dart';

class DashboardStat {
  const DashboardStat(this.label, this.value, this.icon,
      {this.accent = MaestroAccents.blue});
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class DashboardAction {
  const DashboardAction(this.label, this.icon, this.onTap,
      {this.accent = MaestroAccents.blue});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState(this.message,
      {super.key, this.icon = Icons.music_note_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Padding(
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
      ));

  static Widget _block(BuildContext context, double width, double height) =>
      Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14)));
}

class DashboardHero extends StatelessWidget {
  const DashboardHero({super.key, required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 148),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MaestroAccents.blue, MaestroAccents.violet],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: MaestroAccents.blue.withValues(alpha: .18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(
            right: 24,
            top: -4,
            child: ExcludeSemantics(
                child: Icon(Icons.music_note_rounded,
                    size: 84, color: Colors.white.withValues(alpha: .17))),
          ),
          Positioned(
            right: -2,
            bottom: -25,
            child: ExcludeSemantics(
                child: Icon(Icons.graphic_eq_rounded,
                    size: 104, color: Colors.white.withValues(alpha: .12))),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MAESTRO',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: .9),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                Text(greeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Your music, in motion.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: .94))),
              ]),
        ]),
      );
}

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({super.key, required this.stat});
  final DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = MaestroAccents.foreground(stat.accent, theme.brightness);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MaestroAccents.tint(
            stat.accent, theme.colorScheme.surface, theme.brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stat.accent.withValues(alpha: .16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(stat.icon, size: 21, color: accent),
        ),
        const Spacer(),
        Text(stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(stat.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class DashboardActionTile extends StatelessWidget {
  const DashboardActionTile({super.key, required this.action});
  final DashboardAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = action.onTap != null;
    return Tooltip(
      message: enabled ? action.label : 'Not available yet',
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 1,
        shadowColor: theme.shadowColor.withValues(alpha: .10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: .65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MaestroAccents.tint(action.accent,
                      theme.colorScheme.surface, theme.brightness),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon,
                    size: 24,
                    color: enabled
                        ? MaestroAccents.foreground(
                            action.accent, theme.brightness)
                        : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 9),
              Text(action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          enabled ? null : theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
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
                    DashboardHero(greeting: greeting),
                    if (top != null) ...[const SizedBox(height: 16), top!],
                    const SizedBox(height: 24),
                    _grid(context, stats.length, statColumns, 150,
                        (index) => DashboardStatCard(stat: stats[index])),
                    const SizedBox(height: 28),
                    Text('Quick actions',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _grid(context, actions.length, actionColumns, 126,
                        (index) => DashboardActionTile(action: actions[index])),
                    const SizedBox(height: 28),
                    Text('Coming up',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
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
