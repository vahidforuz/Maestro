import 'package:flutter/material.dart';

class MaestroDestination {
  const MaestroDestination(this.label, this.icon, this.onTap, {this.badge = 0});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
}

/// The same five primary destinations are used on phones and wide screens.
/// Secondary destinations stay in the end drawer on every form factor.
class MaestroShell extends StatelessWidget {
  const MaestroShell({
    super.key,
    required this.title,
    required this.userName,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.more,
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
  final List<MaestroDestination> more;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onSignOut;
  final VoidCallback? onNotifications;
  final VoidCallback? onRefresh;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/maestro-icon.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
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
            icon: _badged(Icons.notifications_outlined, unreadCount),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile menu',
            icon: CircleAvatar(
              radius: 17,
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
        child: SafeArea(
          child: ListView(children: [
            const ListTile(title: Text('More')),
            for (final item in more)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              ),
            const Divider(),
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
              NavigationRail(
                selectedIndex: selectedIndex >= 4 ? null : selectedIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (index) => destinations[index].onTap(),
                trailing: Builder(
                    builder: (railContext) => IconButton(
                          tooltip: 'More',
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () =>
                              Scaffold.of(railContext).openEndDrawer(),
                        )),
                destinations: [
                  for (final item in destinations)
                    NavigationRailDestination(
                      icon: _badged(item.icon, item.badge),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : Builder(
              builder: (navContext) => NavigationBar(
                    selectedIndex: selectedIndex.clamp(0, 4),
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
                          icon: Icon(Icons.more_horiz), label: 'More'),
                    ],
                  )),
    );
    return scaffold;
  }

  static Widget _badged(IconData icon, int count) => Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
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
