import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../ui/app_drawer.dart';
import '../ui/widgets.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  Verdict? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final dt = DateFormat('dd/MM HH:mm');
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(context.t('History')),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            CenteredMessage(context.t('Failed to load: {error}', {'error': e})),
        data: (all) {
          final list = _filter == null
              ? all
              : all.where((i) => i.verdict == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.t('All ({n})', {'n': all.length})),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final v in Verdict.values)
                    ChoiceChip(
                      label: Text(
                        '${context.t(v.shortLabel)} (${all.where((i) => i.verdict == v).length})',
                      ),
                      selected: _filter == v,
                      onSelected: (_) => setState(() => _filter = v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                CenteredMessage(context.t('No inspections yet.')),
              for (final i in list)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(vehicleIcon(i.vehicle.type)),
                    ),
                    title: Text('${i.vehicle.plate} · ${i.id}'),
                    subtitle: Text(
                      '${i.inspector.name} · ${dt.format(i.submittedAt)}',
                    ),
                    trailing: VerdictChip(i.verdict),
                    onTap: () => context.push('/report/${i.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
