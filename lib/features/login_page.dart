import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectors = ref.watch(inspectorsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [ThemeToggleButton()]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.fact_check,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                context.t('Fleet Inspection'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.t(
                  'Electronic pre-trip checklist · demo with mock data',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Text(context.t('Sign in as'), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...inspectors.when(
                loading: () => [
                  const Center(child: CircularProgressIndicator()),
                ],
                error: (e, _) => [
                  CenteredMessage(
                    context.t('Failed to load: {error}', {'error': e}),
                  ),
                ],
                data: (list) => [
                  for (final inspector in list)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(inspector.name[0])),
                        title: Text(inspector.name),
                        subtitle: Text(inspector.depot),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ref.read(sessionProvider.notifier).signIn(inspector);
                          context.go('/dashboard');
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
