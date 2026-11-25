import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/dashboard_page.dart';
import 'features/fleet_page.dart';
import 'features/history_page.dart';
import 'features/inspection_page.dart';
import 'features/login_page.dart';
import 'features/report_page.dart';
import 'features/settings_page.dart';
import 'l10n/l10n.dart';
import 'state/providers.dart';
import 'ui/app_drawer.dart';
import 'ui/theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      if (atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/fleet', builder: (_, _) => const FleetPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/inspect/:vehicleId',
        builder: (_, s) =>
            InspectionPage(vehicleId: s.pathParameters['vehicleId']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/report/:id',
        builder: (_, s) => ReportPage(inspectionId: s.pathParameters['id']!),
      ),
    ],
  );
});

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: homeScaffoldKey,
    drawer: AppDrawer(currentIndex: shell.currentIndex, onGo: shell.goBranch),
    body: shell,
  );
}

class InspectionApp extends ConsumerWidget {
  const InspectionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(useGoogleFontsProvider);
    final language = ref.watch(languageProvider);
    return MaterialApp.router(
      title: translate(language, 'Fleet Inspection'),
      builder: (context, child) => L10nScope(language: language, child: child!),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, useGoogleFonts: fonts),
      darkTheme: buildTheme(Brightness.dark, useGoogleFonts: fonts),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
