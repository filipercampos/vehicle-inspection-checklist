import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/mock_data.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../ui/car3d/vehicle_viewer.dart';
import '../ui/signature_pad.dart';
import '../ui/theme.dart';
import 'damage_map.dart';
import '../ui/widgets.dart';

class ReportPage extends ConsumerWidget {
  const ReportPage({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionByIdProvider(inspectionId));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Report {id}', {'id': inspectionId})),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/history'),
        ),
      ),
      body: inspection.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenteredMessage(
          context.t('Inspection not found: {error}', {'error': e}),
        ),
        data: (i) => _ReportBody(inspection: i),
      ),
      // Always-visible way out once the inspection is done.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('report-done'),
                  onPressed: () => context.go('/fleet'),
                  icon: const Icon(Icons.check),
                  label: Text(context.t('Back to fleet')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    final theme = Theme.of(context);
    final dt = DateFormat('dd/MM/yyyy HH:mm');
    final km = NumberFormat.decimalPattern('pt_BR');
    // Mock keeps one template version per type; a real backend would fetch
    // the exact templateId + templateVersion stored on the inspection.
    final template = MockData.templates[i.vehicle.type]!;
    final duration = i.submittedAt.difference(i.startedAt);
    final defects = template.allItems
        .where((it) => i.answers[it.id]?.status == ItemStatus.defect)
        .toList();

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VerdictBanner(
              i.verdict,
              subtitle: context.t('{plate} · {n} defect(s)', {
                'plate': i.vehicle.plate,
                'n': i.defectCount,
              }),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    row(
                      context.t('Vehicle'),
                      '${i.vehicle.plate} — ${i.vehicle.model}',
                    ),
                    row(context.t('Inspector'), i.inspector.name),
                    row(context.t('Depot'), i.vehicle.depot),
                    row(context.t('Submitted'), dt.format(i.submittedAt)),
                    row(context.t('Duration'), '${duration.inMinutes} min'),
                    row(context.t('Odometer'), '${km.format(i.odometerKm)} km'),
                    row(context.t('Fuel'), context.t(i.fuel.label)),
                    row(
                      context.t('Template'),
                      '${i.templateId} v${i.templateVersion}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      i.damages.isEmpty
                          ? context.t('Body damage · none recorded')
                          : context.t('Body damage · {n} part(s)', {
                              'n': i.damages.length,
                            }),
                      style: theme.textTheme.titleMedium,
                    ),
                    VehicleViewer(
                      type: i.vehicle.type,
                      damages: i.damages,
                      height: 220,
                    ),
                    DamageList(damages: i.damages),
                  ],
                ),
              ),
            ),
            if (defects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.t('Defects'), style: theme.textTheme.titleMedium),
              for (final d in defects)
                Card(
                  color: d.critical
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(d.critical ? Icons.block : Icons.build),
                    title: Row(
                      children: [
                        Flexible(child: Text(context.t(d.label))),
                        if (d.critical) const CriticalBadge(),
                      ],
                    ),
                    subtitle: Text(i.answers[d.id]!.note),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(context.t('All items'), style: theme.textTheme.titleMedium),
            for (final s in template.sections)
              Card(
                child: ExpansionTile(
                  title: Text(context.t(s.title)),
                  children: [
                    for (final it in s.items)
                      ListTile(
                        dense: true,
                        title: Text(context.t(it.label)),
                        trailing: _statusIcon(i.answers[it.id]?.status, theme),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(context.t('Signature'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: SignaturePainter(
                  i.signature,
                  theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(ItemStatus? s, ThemeData theme) => switch (s) {
    ItemStatus.ok => Icon(
      Icons.check,
      color: AppPalette.of(theme.brightness).ok,
    ),
    ItemStatus.defect => Icon(Icons.close, color: theme.colorScheme.error),
    ItemStatus.notApplicable => const Text('N/A'),
    null => const Text('—'),
  };
}
