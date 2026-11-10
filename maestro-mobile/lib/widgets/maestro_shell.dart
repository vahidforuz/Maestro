import 'package:flutter/material.dart';

import '../theme/maestro_theme.dart';

class MaestroDestination {
  const MaestroDestination(this.label, this.icon, this.onTap, {this.badge = 0});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
}

class MaestroShortcut {
  const MaestroShortcut(this.label, this.icon, this.color, this.onTap,
      {this.selected = false});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
}

/// The primary destinations remain in the mobile bar. Authorized features
/// join the left rail on wide screens and the More drawer on phones.
class MaestroShell extends StatelessWidget {
  const MaestroShell({
    super.key,
    required this.title,
    required this.userName,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    this.shortcuts = const [],
    required this.onProfile,
    required this.onSettings,
    required this.onSignOut,
    this.onNotifications,
    this.onRefresh,
    this.unreadCount = 0,
  }) : assert(destinations.length == 4);

  final String title;
  final String userName;
  final Widget body;
  final List<MaestroDestination> destinations;
  final int selectedIndex;
  final List<MaestroShortcut> shortcuts;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final VoidCallback? onNotifications;
  final VoidCallback? onRefresh;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final surface = Theme.of(context).colorScheme.surface;
    final selectedShortcut = shortcuts.indexWhere((item) => item.selected);
    final railSelectedIndex = selectedShortcut >= 0
        ? 4 + selectedShortcut
        : selectedIndex == 4
            ? 4 + shortcuts.length
            : selectedIndex;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/maestro-icon.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Flexible(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        actions: [
          if (onRefresh != null)
            IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications ?? destinations[3].onTap,
            style: IconButton.styleFrom(
              backgroundColor: MaestroAccents.tint(
                  MaestroAccents.pink, surface, Theme.of(context).brightness),
              foregroundColor: MaestroAccents.foreground(
                  MaestroAccents.pink, Theme.of(context).brightness),
            ),
            icon: _badged(Icons.notifications_outlined, unreadCount),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile menu',
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: MaestroAccents.tint(
                  MaestroAccents.blue, surface, Theme.of(context).brightness),
              foregroundColor: MaestroAccents.foreground(
                  MaestroAccents.blue, Theme.of(context).brightness),
              child: Text(userName.trim().isEmpty
                  ? '?'
                  : userName.trim().substring(0, 1).toUpperCase()),
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  onProfile();
                case 'settings':
                  onSettings();
                case 'help':
                  _help(context);
                case 'signout':
                  onSignOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(userName)),
              const PopupMenuItem(value: 'profile', child: Text('My Profile')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'help', child: Text('Help')),
              const PopupMenuItem(value: 'signout', child: Text('Sign Out')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: Drawer(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(24))),
        child: SafeArea(
          child: ListView(children: [
            const ListTile(title: Text('More')),
            if (!wide) ...[
              for (final shortcut in shortcuts)
                ListTile(
                  key: ValueKey('shortcut-${shortcut.label}'),
                  leading: Icon(shortcut.icon,
                      color: MaestroAccents.foreground(
                          shortcut.color, Theme.of(context).brightness)),
                  title: Text(shortcut.label),
                  selected: shortcut.selected,
                  onTap: () {
                    Navigator.pop(context);
                    shortcut.onTap();
                  },
                ),
              if (shortcuts.isNotEmpty) const Divider(),
            ],
            ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  onProfile();
                }),
            ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  onSettings();
                }),
            ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help'),
                onTap: () {
                  Navigator.pop(context);
                  _help(context);
                }),
            ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () {
                  Navigator.pop(context);
                  onSignOut();
                }),
          ]),
        ),
      ),
      body: wide
          ? Row(children: [
              Builder(
                  builder: (railContext) => NavigationRail(
                        selectedIndex: railSelectedIndex,
                        labelType: NavigationRailLabelType.all,
                        scrollable: true,
                        onDestinationSelected: (index) {
                          if (index < destinations.length) {
                            destinations[index].onTap();
                          } else if (index <
                              destinations.length + shortcuts.length) {
                            shortcuts[index - destinations.length].onTap();
                          } else {
                            Scaffold.of(railContext).openEndDrawer();
                          }
                        },
                        destinations: [
                          for (final item in destinations)
                            NavigationRailDestination(
                              icon: _badged(item.icon, item.badge),
                              label: Text(item.label),
                            ),
                          for (final shortcut in shortcuts)
                            NavigationRailDestination(
                              icon: Icon(shortcut.icon,
                                  key: ValueKey('shortcut-${shortcut.label}')),
                              label: Text(shortcut.label),
                            ),
                          const NavigationRailDestination(
                            icon: Icon(Icons.more_horiz),
                            label: Text('More'),
                          ),
                        ],
                      )),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context)
                              .shadowColor
                              .withValues(alpha: .14),
                          blurRadius: 22,
                          offset: const Offset(0, 7))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Builder(
                        builder: (navContext) => NavigationBar(
                              height: 72,
                              animationDuration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              backgroundColor: surface,
                              selectedIndex: selectedShortcut >= 0
                                  ? 4
                                  : selectedIndex.clamp(0, 4),
                              onDestinationSelected: (index) {
                                if (index == 4) {
                                  Scaffold.of(navContext).openEndDrawer();
                                } else {
                                  destinations[index].onTap();
                                }
                              },
                              destinations: [
                                for (final item in destinations)
                                  NavigationDestination(
                                      icon: _badged(item.icon, item.badge),
                                      label: item.label),
                                const NavigationDestination(
                                    icon: Icon(Icons.more_horiz),
                                    label: 'More'),
                              ],
                            )),
                  ),
                ),
              )),
    );
    return scaffold;
  }

  static Widget _badged(IconData icon, int count) => Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: MaestroAccents.pink,
        child: Icon(icon),
      );

  static void _help(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Help'),
          content: const Text(
              'For help with your Maestro account, contact your music teacher or studio.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
}
