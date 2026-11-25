import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/theme.dart';

/// User preferences: language and theme.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final theme = Theme.of(context);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        context.t(text),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Settings')),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              heading('Language'),
              Card(
                child: RadioGroup<AppLanguage>(
                  groupValue: language,
                  onChanged: (l) {
                    if (l != null) ref.read(languageProvider.notifier).set(l);
                  },
                  child: Column(
                    children: [
                      for (final l in AppLanguage.values)
                        RadioListTile<AppLanguage>(
                          key: Key('language-${l.name}'),
                          value: l,
                          title: Text(l.label),
                        ),
                    ],
                  ),
                ),
              ),
              heading('Appearance'),
              Card(
                child: SwitchListTile(
                  key: const Key('dark-theme'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(context.t('Dark theme')),
                  value: dark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
