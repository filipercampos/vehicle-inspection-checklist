import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/draft_notifier.dart';
import '../ui/car3d/vehicle_viewer.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Editable body-damage checklist on top of the 3D vehicle.
class DamageMapCard extends ConsumerWidget {
  const DamageMapCard({super.key, required this.vehicleId, required this.type});

  final String vehicleId;
  final VehicleType type;

  Future<void> _edit(BuildContext context, WidgetRef ref, CarPart part) async {
    final notifier = ref.read(draftProvider(vehicleId).notifier);
    final current = ref.read(draftProvider(vehicleId)).damages[part];
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DamageSheet(part: part, current: current),
    );
    switch (result) {
      case _Save(:final mark):
        notifier.setDamage(mark);
      case _Remove():
        notifier.removeDamage(part);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damages = ref.watch(draftProvider(vehicleId)).damages;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.car_crash_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('Body damage'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  damages.isEmpty
                      ? context.t('No damage')
                      : context.t('{n} part(s) damaged', {'n': damages.length}),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            VehicleViewer(
              type: type,
              damages: damages,
              onPartTap: (p) => _edit(context, ref, p),
            ),
            const SizedBox(height: 8),
            DamageList(damages: damages, onTap: (p) => _edit(context, ref, p)),
          ],
        ),
      ),
    );
  }
}

/// Damage marks as a list (also the accessible alternative to the 3D view).
class DamageList extends StatelessWidget {
  const DamageList({super.key, required this.damages, this.onTap});

  final Map<CarPart, DamageMark> damages;
  final ValueChanged<CarPart>? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.ofContext(context);
    if (damages.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _Legend(palette: p),
        for (final d in damages.values)
          ListTile(
            key: Key('damage-${d.part.name}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              d.type.severe ? Icons.report : Icons.brush_outlined,
              color: d.type.severe ? p.bad : p.amber,
            ),
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${context.t(d.part.label)} · ${context.t(d.type.label)}'),
                if (d.blocking) const CriticalBadge(),
              ],
            ),
            subtitle: d.note.isEmpty ? null : Text(d.note),
            trailing: onTap == null ? null : const Icon(Icons.edit, size: 18),
            onTap: onTap == null ? null : () => onTap!(d.part),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          context.t(label),
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 16,
        children: [
          dot(palette.amber, 'Cosmetic'),
          dot(palette.bad, 'Broken / missing'),
        ],
      ),
    );
  }
}

sealed class _SheetResult {}

class _Save extends _SheetResult {
  _Save(this.mark);
  final DamageMark mark;
}

class _Remove extends _SheetResult {}

class _DamageSheet extends StatefulWidget {
  const _DamageSheet({required this.part, required this.current});

  final CarPart part;
  final DamageMark? current;

  @override
  State<_DamageSheet> createState() => _DamageSheetState();
}

class _DamageSheetState extends State<_DamageSheet> {
  late DamageType? _type = widget.current?.type;
  late final _note = TextEditingController(text: widget.current?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocking = _type != null && widget.part.safety && _type!.severe;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.t(widget.part.label),
                style: theme.textTheme.titleLarge,
              ),
              if (widget.part.safety)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    context.t('safety part'),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in DamageType.values)
                ChoiceChip(
                  label: Text(context.t(t.label)),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('Notes (size, position…)'),
            ),
          ),
          if (blocking) ...[
            const SizedBox(height: 12),
            Text(
              context.t('A broken or missing safety part blocks the vehicle.'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.current != null)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, _Remove()),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.t('Remove')),
                ),
              const Spacer(),
              FilledButton(
                key: const Key('save-damage'),
                onPressed: _type == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        _Save(
                          DamageMark(
                            part: widget.part,
                            type: _type!,
                            note: _note.text.trim(),
                          ),
                        ),
                      ),
                child: Text(context.t('Save damage')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
