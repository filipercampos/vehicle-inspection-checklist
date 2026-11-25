import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../state/providers.dart';

/// Scaffold of the home shell; it owns the navigation drawer.
final homeScaffoldKey = GlobalKey<ScaffoldState>();

/// Hamburger button for the app bars of the home pages.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('menu-button'),
    tooltip: context.t('Menu'),
    icon: const Icon(Icons.menu),
    onPressed: () => homeScaffoldKey.currentState?.openDrawer(),
  );
}

/// Main navigation: home pages, settings and, pinned to the bottom, sign out.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.currentIndex, required this.onGo});

  final int currentIndex;
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);

    Widget destination(int index, IconData icon, String label) => ListTile(
      key: Key('drawer-$index'),
      leading: Icon(icon),
      title: Text(context.t(label)),
      selected: index == currentIndex,
      onTap: () {
        Navigator.pop(context);
        onGo(index);
      },
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (session != null)
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      leading: CircleAvatar(child: Text(session.name[0])),
                      title: Text(
                        session.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Text(session.depot),
                    ),
                  const Divider(),
                  destination(0, Icons.home_outlined, 'Home'),
                  destination(1, Icons.garage_outlined, 'Fleet'),
                  destination(2, Icons.history, 'History'),
                  const Divider(),
                  ListTile(
                    key: const Key('drawer-settings'),
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.t('Settings')),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('sign-out'),
              leading: const Icon(Icons.logout),
              title: Text(context.t('Sign out')),
              onTap: () {
                Navigator.pop(context);
                ref.read(sessionProvider.notifier).signOut();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
