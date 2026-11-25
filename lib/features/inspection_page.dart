import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/inspection_rules.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/draft_notifier.dart';
import '../state/providers.dart';
import '../ui/signature_pad.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'damage_map.dart';

class InspectionPage extends ConsumerWidget {
  const InspectionPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    return vehicle.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: CenteredMessage('$e')),
      data: (v) => ref
          .watch(templateProvider(v.type))
          .when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) =>
                Scaffold(appBar: AppBar(), body: CenteredMessage('$e')),
            data: (t) => _InspectionWizard(vehicle: v, template: t),
          ),
    );
  }
}

/// One page of the wizard.
sealed class _Step {
  const _Step();

  String get title;
  IconData get icon;
}

class _ReadingsStep extends _Step {
  const _ReadingsStep();

  @override
  String get title => 'Vehicle';
  @override
  IconData get icon => Icons.speed;
}

class _BodyStep extends _Step {
  const _BodyStep();

  @override
  String get title => 'Body';
  @override
  IconData get icon => Icons.car_crash_outlined;
}

class _SectionStep extends _Step {
  const _SectionStep(this.section);

  final ChecklistSection section;

  @override
  String get title => section.title;
  @override
  IconData get icon => Icons.checklist;
}

class _ReviewStep extends _Step {
  const _ReviewStep();

  @override
  String get title => 'Review';
  @override
  IconData get icon => Icons.draw_outlined;
}

enum _StepState { todo, done, issue }

/// Step-by-step inspection: readings → body damage → one page per checklist
/// section → review, sign and submit. Each step is validated before moving on.
class _InspectionWizard extends ConsumerStatefulWidget {
  const _InspectionWizard({required this.vehicle, required this.template});

  final Vehicle vehicle;
  final ChecklistTemplate template;

  @override
  ConsumerState<_InspectionWizard> createState() => _InspectionWizardState();
}

class _InspectionWizardState extends ConsumerState<_InspectionWizard> {
  late final List<_Step> _steps = [
    const _ReadingsStep(),
    const _BodyStep(),
    for (final s in widget.template.sections) _SectionStep(s),
    const _ReviewStep(),
  ];
  final _pages = PageController();
  late final _chipKeys = [for (final _ in _steps) GlobalKey()];

  int _index = 0;
  int _furthest = 0;

  /// Steps where the user tried to continue with errors: show them inline.
  final _attempted = <int>{};
  bool _submitting = false;

  DraftNotifier get _draft =>
      ref.read(draftProvider(widget.vehicle.id).notifier);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<String> _errorsFor(_Step step, InspectionDraft d) => switch (step) {
    _ReadingsStep() => InspectionRules.readingErrors(
      vehicle: widget.vehicle,
      odometerKm: d.odometerKm,
      fuel: d.fuel,
    ),
    _BodyStep() => const [],
    _SectionStep(:final section) => InspectionRules.sectionErrors(
      section,
      d.answers,
    ),
    _ReviewStep() => InspectionRules.validate(
      template: widget.template,
      answers: d.answers,
      vehicle: widget.vehicle,
      odometerKm: d.odometerKm,
      fuel: d.fuel,
      signed: d.signed,
    ),
  };

  _StepState _stateOf(int i, InspectionDraft d) {
    final step = _steps[i];
    if (step is _SectionStep) {
      final items = step.section.items;
      if (items.any((it) => d.answers[it.id]?.status == ItemStatus.defect)) {
        return _StepState.issue;
      }
      if (items.every((it) => d.answers.containsKey(it.id))) {
        return _StepState.done;
      }
      return _StepState.todo;
    }
    if (step is _BodyStep) {
      if (d.damages.isNotEmpty) return _StepState.issue;
      return i < _furthest ? _StepState.done : _StepState.todo;
    }
    if (step is _ReadingsStep) {
      return _errorsFor(step, d).isEmpty ? _StepState.done : _StepState.todo;
    }
    return _StepState.todo;
  }

  void _goTo(int i) {
    FocusScope.of(context).unfocus();
    setState(() {
      _index = i;
      if (i > _furthest) _furthest = i;
    });
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[i].currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  void _next() {
    final draft = ref.read(draftProvider(widget.vehicle.id));
    final errors = _errorsFor(_steps[_index], draft);
    if (errors.isNotEmpty) {
      setState(() => _attempted.add(_index));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.t(errors.first))));
      return;
    }
    _goTo(_index + 1);
  }

  Future<void> _submit() async {
    final inspector = ref.read(sessionProvider);
    if (inspector == null) return;
    setState(() {
      _submitting = true;
      _attempted.add(_index);
    });
    try {
      final saved = await _draft.submit(
        vehicle: widget.vehicle,
        inspector: inspector,
        template: widget.template,
      );
      if (mounted) context.pushReplacement('/report/${saved.id}');
    } on StateError {
      // Validation errors are rendered on the review step.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider(widget.vehicle.id));
    final v = widget.vehicle;
    final step = _steps[_index];
    final last = _index == _steps.length - 1;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Inspect {plate}', {'plate': v.plate})),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_index + 1) / _steps.length),
            duration: const Duration(milliseconds: 280),
            builder: (_, value, _) => LinearProgressIndicator(value: value),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _steps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _StepChip(
                key: _chipKeys[i],
                number: i + 1,
                step: _steps[i],
                state: _stateOf(i, draft),
                current: i == _index,
                enabled: i <= _furthest,
                onTap: () => _goTo(i),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.t('Step {n} of {total} · {title}', {
                  'n': _index + 1,
                  'total': _steps.length,
                  'title': context.t(step.title),
                }),
                key: const Key('step-title'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              // Swiping would fight with rotating the 3D model.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < _steps.length; i++)
                  _StepPage(
                    child: _buildStep(
                      _steps[i],
                      draft,
                      showErrors: _attempted.contains(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: [
                  if (_index > 0)
                    OutlinedButton.icon(
                      key: const Key('wizard-back'),
                      onPressed: () => _goTo(_index - 1),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.t('Back')),
                    ),
                  const Spacer(),
                  if (last)
                    FilledButton.icon(
                      key: const Key('submit'),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(context.t('Submit inspection')),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('wizard-next'),
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        context.t(
                          step is _BodyStep && draft.damages.isEmpty
                              ? 'No damage, next'
                              : 'Next',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    _Step step,
    InspectionDraft draft, {
    required bool showErrors,
  }) {
    final v = widget.vehicle;
    return switch (step) {
      _ReadingsStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: Icon(vehicleIcon(v.type), size: 32),
              title: Text('${v.plate} · ${v.model}'),
              subtitle: Text(
                context.t('{name} · template v{version}', {
                  'name': context.t(widget.template.name),
                  'version': widget.template.version,
                }),
              ),
            ),
          ),
          _ReadingsCard(vehicle: v, draft: draft, showErrors: showErrors),
        ],
      ),
      _BodyStep() => DamageMapCard(vehicleId: v.id, type: v.type),
      _SectionStep(:final section) => _SectionPage(
        vehicleId: v.id,
        section: section,
        answers: draft.answers,
        showErrors: showErrors,
      ),
      _ReviewStep() => _ReviewPage(
        template: widget.template,
        draft: draft,
        errors: showErrors ? _errorsFor(step, draft) : const [],
        onEdit: (section) => _goTo(
          _steps.indexWhere(
            (s) => s is _SectionStep && s.section.id == section.id,
          ),
        ),
        onSign: _draft.setSignature,
      ),
    };
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: child,
        ),
      ),
    ],
  );
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    super.key,
    required this.number,
    required this.step,
    required this.state,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final _Step step;
  final _StepState state;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.ofContext(context);
    final (Color color, Widget badge) = switch (state) {
      _StepState.done => (p.ok, Icon(Icons.check, size: 14, color: p.ok)),
      _StepState.issue => (
        p.warn,
        Icon(Icons.priority_high, size: 14, color: p.warn),
      ),
      _StepState.todo => (
        current ? p.accent : p.muted,
        Text(
          '$number',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: current ? p.accent : p.muted,
          ),
        ),
      ),
    };
    return Material(
      color: current ? p.accent.withValues(alpha: 0.14) : p.surface,
      shape: StadiumBorder(
        side: BorderSide(color: current ? p.accent : p.line2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: badge,
              ),
              const SizedBox(width: 6),
              Text(
                context.t(step.title),
                style: TextStyle(
                  fontSize: 13,
                  color: enabled ? p.text : p.muted,
                  fontWeight: current ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionPage extends ConsumerWidget {
  const _SectionPage({
    required this.vehicleId,
    required this.section,
    required this.answers,
    required this.showErrors,
  });

  final String vehicleId;
  final ChecklistSection section;
  final Map<String, ItemAnswer> answers;
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = section.items.where((i) => answers.containsKey(i.id)).length;
    final defects = section.items
        .where((i) => answers[i.id]?.status == ItemStatus.defect)
        .length;
    final complete = done == section.items.length;
    final notifier = ref.read(draftProvider(vehicleId).notifier);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              context.t(section.title),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              context.t('{done}/{total} answered', {
                    'done': done,
                    'total': section.items.length,
                  }) +
                  (defects > 0
                      ? ' · ${context.t('{n} defect(s)', {'n': defects})}'
                      : ''),
            ),
            trailing: complete
                ? null
                : TextButton.icon(
                    key: const Key('all-ok'),
                    onPressed: () => notifier.markSectionOk(section),
                    icon: const Icon(Icons.done_all),
                    label: Text(context.t('All OK')),
                  ),
          ),
          const Divider(height: 1),
          for (final item in section.items)
            _ItemRow(
              item: item,
              answer: answers[item.id],
              showErrors: showErrors,
              onStatus: (s) => notifier.setStatus(item.id, s),
              onNote: (n) => notifier.setNote(item.id, n),
            ),
        ],
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.template,
    required this.draft,
    required this.errors,
    required this.onEdit,
    required this.onSign,
  });

  final ChecklistTemplate template;
  final InspectionDraft draft;
  final List<String> errors;
  final ValueChanged<ChecklistSection> onEdit;
  final ValueChanged<List<List<Offset>>> onSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.ofContext(context);
    final km = NumberFormat.decimalPattern('pt_BR');
    final verdict = InspectionRules.verdictFor(
      template,
      draft.answers,
      draft.damages,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VerdictBanner(verdict, subtitle: context.t('Result if submitted now')),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.speed),
                title: Text(context.t('Readings')),
                trailing: Text(
                  '${draft.odometerKm == null ? '—' : '${km.format(draft.odometerKm)} km'}'
                  ' · ${draft.fuel == null ? '—' : context.t(draft.fuel!.label)}',
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.car_crash_outlined),
                title: Text(context.t('Body damage')),
                trailing: Text(
                  draft.damages.isEmpty
                      ? context.t('None')
                      : context.t('{n} part(s)', {'n': draft.damages.length}),
                ),
              ),
              for (final s in template.sections)
                () {
                  final items = s.items;
                  final done = items
                      .where((i) => draft.answers.containsKey(i.id))
                      .length;
                  final defects = items
                      .where(
                        (i) => draft.answers[i.id]?.status == ItemStatus.defect,
                      )
                      .length;
                  return ListTile(
                    dense: true,
                    onTap: () => onEdit(s),
                    leading: Icon(
                      defects > 0
                          ? Icons.error_outline
                          : done == items.length
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: defects > 0
                          ? p.warn
                          : done == items.length
                          ? p.ok
                          : null,
                    ),
                    title: Text(context.t(s.title)),
                    trailing: Text(
                      defects > 0
                          ? context.t('{n} defect(s)', {'n': defects})
                          : '$done/${items.length}',
                    ),
                  );
                }(),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('Inspector signature'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SignaturePad(strokes: draft.signature, onChanged: onSign),
              ],
            ),
          ),
        ),
        if (errors.isNotEmpty)
          Card(
            key: const Key('validation-errors'),
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final e in errors) Text('• ${context.t(e)}')],
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.answer,
    required this.showErrors,
    required this.onStatus,
    required this.onNote,
  });

  final ChecklistItem item;
  final ItemAnswer? answer;
  final bool showErrors;
  final ValueChanged<ItemStatus> onStatus;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    final missing = showErrors && answer == null;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('item-${item.id}'),
      color: missing ? scheme.errorContainer.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.t(item.label)),
              if (item.critical) const CriticalBadge(),
            ],
          ),
          if (item.hint != null)
            Text(
              context.t(item.hint!),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 6),
          SegmentedButton<ItemStatus>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ItemStatus.ok,
                label: Text(context.t('OK')),
                icon: const Icon(Icons.check),
              ),
              ButtonSegment(
                value: ItemStatus.defect,
                label: Text(context.t('Defect')),
                icon: const Icon(Icons.close),
              ),
              ButtonSegment(
                value: ItemStatus.notApplicable,
                label: Text(context.t('N/A')),
                enabled: !item.critical,
              ),
            ],
            selected: {if (answer != null) answer!.status},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onStatus(s.first);
            },
          ),
          if (answer?.status == ItemStatus.defect) ...[
            const SizedBox(height: 8),
            _NoteField(
              initial: answer!.note,
              onChanged: onNote,
              showError: showErrors && answer!.note.trim().isEmpty,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({
    required this.initial,
    required this.onChanged,
    required this.showError,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final bool showError;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    maxLines: 2,
    decoration: InputDecoration(
      labelText: context.t('Describe the defect'),
      border: const OutlineInputBorder(),
      isDense: true,
      errorText: widget.showError ? context.t('Required for defects') : null,
    ),
  );
}

class _ReadingsCard extends ConsumerStatefulWidget {
  const _ReadingsCard({
    required this.vehicle,
    required this.draft,
    required this.showErrors,
  });

  final Vehicle vehicle;
  final InspectionDraft draft;
  final bool showErrors;

  @override
  ConsumerState<_ReadingsCard> createState() => _ReadingsCardState();
}

class _ReadingsCardState extends ConsumerState<_ReadingsCard> {
  late final _odometer = TextEditingController(
    text: widget.draft.odometerKm?.toString() ?? '',
  );

  @override
  void dispose() {
    _odometer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(draftProvider(widget.vehicle.id).notifier);
    final km = NumberFormat.decimalPattern('pt_BR');
    final odo = widget.draft.odometerKm;
    String? odoError;
    if (widget.showErrors && odo == null) odoError = context.t('Required');
    if (odo != null && odo < widget.vehicle.odometerKm) {
      odoError = context.t('Lower than last reading');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Readings'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('odometer'),
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (s) => notifier.setOdometer(int.tryParse(s)),
              decoration: InputDecoration(
                labelText: context.t('Odometer (km)'),
                helperText: context.t('Last reading: {km} km', {
                  'km': km.format(widget.vehicle.odometerKm),
                }),
                border: const OutlineInputBorder(),
                errorText: odoError,
                suffixIcon: IconButton(
                  tooltip: context.t('Use last reading'),
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    _odometer.text = widget.vehicle.odometerKm.toString();
                    notifier.setOdometer(widget.vehicle.odometerKm);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.t('Fuel level'),
              style: TextStyle(
                color: widget.showErrors && widget.draft.fuel == null
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<FuelLevel>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  for (final f in FuelLevel.values)
                    ButtonSegment(value: f, label: Text(context.t(f.label))),
                ],
                selected: {if (widget.draft.fuel != null) widget.draft.fuel!},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) notifier.setFuel(s.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
