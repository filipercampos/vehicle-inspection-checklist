import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/mock_data.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../ui/app_drawer.dart';
import '../ui/widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final latest = ref.watch(latestByVehicleProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(context.t('Home')),
      ),
      body: switch ((history, vehicles, latest)) {
        (
          AsyncData(value: final h),
          AsyncData(value: final v),
          AsyncData(value: final l),
        ) =>
          _DashboardBody(history: h, vehicles: v, latest: l),
        (AsyncError(:final error), _, _) ||
        (_, AsyncError(:final error), _) ||
        (_, _, AsyncError(:final error)) => CenteredMessage(
          context.t('Failed to load: {error}', {'error': error}),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.history,
    required this.vehicles,
    required this.latest,
  });

  final List<Inspection> history;
  final List<Vehicle> vehicles;
  final Map<String, Inspection> latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = history.where(
      (i) =>
          i.submittedAt.year == now.year &&
          i.submittedAt.month == now.month &&
          i.submittedAt.day == now.day,
    );
    final blocked = vehicles
        .where((v) => latest[v.id]?.verdict == Verdict.blocked)
        .toList();
    final notInspected = vehicles
        .where((v) => !latest.containsKey(v.id))
        .length;

    // Most frequent defects across all inspections.
    final labels = {
      for (final t in MockData.templates.values)
        for (final it in t.allItems) it.id: it.label,
    };
    final counts = <String, int>{};
    for (final i in history) {
      for (final e in i.answers.entries) {
        if (e.value.status == ItemStatus.defect) {
          counts[e.key] = (counts[e.key] ?? 0) + 1;
        }
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi(
              context.t('Inspections today'),
              '${today.length}',
              Icons.today,
            ),
            _Kpi(
              context.t('Total inspections'),
              '${history.length}',
              Icons.fact_check,
            ),
            _Kpi(
              context.t('Vehicles blocked'),
              '${blocked.length}',
              Icons.block,
              color: blocked.isEmpty ? null : theme.colorScheme.error,
            ),
            _Kpi(
              context.t('Never inspected'),
              '$notInspected',
              Icons.help_outline,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.t('Fleet status (latest inspection)'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _StatusBar(vehicles: vehicles, latest: latest),
        const SizedBox(height: 20),
        if (blocked.isNotEmpty) ...[
          Text(
            context.t('Blocked vehicles'),
            style: theme.textTheme.titleMedium,
          ),
          for (final v in blocked)
            Card(
              child: ListTile(
                leading: Icon(
                  vehicleIcon(v.type),
                  color: theme.colorScheme.error,
                ),
                title: Text(v.plate),
                subtitle: Text(v.model),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/report/${latest[v.id]!.id}'),
              ),
            ),
          const SizedBox(height: 20),
        ],
        Text(
          context.t('Most frequent defects'),
          style: theme.textTheme.titleMedium,
        ),
        if (top.isEmpty) CenteredMessage(context.t('No defects recorded.')),
        for (final e in top.take(5))
          ListTile(
            dense: true,
            title: Text(labels[e.key] ?? e.key),
            trailing: Text('${e.value}×'),
          ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, {this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color ?? theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.vehicles, required this.latest});

  final List<Vehicle> vehicles;
  final Map<String, Inspection> latest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <(String, Color, int)>[
      for (final v in Verdict.values)
        (
          context.t(v.shortLabel),
          v.color(scheme),
          vehicles.where((x) => latest[x.id]?.verdict == v).length,
        ),
      (
        context.t('Not inspected'),
        scheme.outline,
        vehicles.where((x) => !latest.containsKey(x.id)).length,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                for (final (_, color, n) in groups)
                  if (n > 0)
                    Expanded(
                      flex: n,
                      child: Container(color: color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            for (final (label, color, n) in groups)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: color),
                  const SizedBox(width: 4),
                  Text('$label: $n'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
