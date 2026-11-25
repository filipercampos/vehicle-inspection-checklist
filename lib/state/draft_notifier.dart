import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inspection_rules.dart';
import '../domain/models.dart';
import 'providers.dart';

@immutable
class InspectionDraft {
  const InspectionDraft({
    required this.startedAt,
    this.answers = const {},
    this.odometerKm,
    this.fuel,
    this.signature = const [],
    this.damages = const {},
  });

  final DateTime startedAt;
  final Map<String, ItemAnswer> answers;
  final int? odometerKm;
  final FuelLevel? fuel;
  final List<List<Offset>> signature;
  final Map<CarPart, DamageMark> damages;

  bool get signed => signature.any((stroke) => stroke.length > 1);

  InspectionDraft copyWith({
    Map<String, ItemAnswer>? answers,
    int? Function()? odometerKm,
    FuelLevel? fuel,
    List<List<Offset>>? signature,
    Map<CarPart, DamageMark>? damages,
  }) => InspectionDraft(
    startedAt: startedAt,
    answers: answers ?? this.answers,
    odometerKm: odometerKm != null ? odometerKm() : this.odometerKm,
    fuel: fuel ?? this.fuel,
    signature: signature ?? this.signature,
    damages: damages ?? this.damages,
  );
}

/// In-progress inspection for one vehicle. Not auto-disposed: leaving the
/// screen keeps the draft, like a real app would keep it across interruptions.
class DraftNotifier extends Notifier<InspectionDraft> {
  DraftNotifier(this.vehicleId);

  final String vehicleId;

  @override
  InspectionDraft build() => InspectionDraft(startedAt: DateTime.now());

  void setStatus(String itemId, ItemStatus status) {
    final current = state.answers[itemId];
    final next =
        current?.copyWith(status: status) ?? ItemAnswer(status: status);
    state = state.copyWith(answers: {...state.answers, itemId: next});
  }

  void setNote(String itemId, String note) {
    final current = state.answers[itemId];
    if (current == null) return;
    state = state.copyWith(
      answers: {
        ...state.answers,
        itemId: current.copyWith(note: note),
      },
    );
  }

  /// Marks every unanswered item of a section as OK (common fast path in the field).
  void markSectionOk(ChecklistSection section) {
    final answers = {...state.answers};
    for (final item in section.items) {
      answers.putIfAbsent(
        item.id,
        () => const ItemAnswer(status: ItemStatus.ok),
      );
    }
    state = state.copyWith(answers: answers);
  }

  void setDamage(DamageMark mark) =>
      state = state.copyWith(damages: {...state.damages, mark.part: mark});

  void removeDamage(CarPart part) =>
      state = state.copyWith(damages: {...state.damages}..remove(part));

  void setOdometer(int? km) => state = state.copyWith(odometerKm: () => km);
  void setFuel(FuelLevel fuel) => state = state.copyWith(fuel: fuel);
  void setSignature(List<List<Offset>> strokes) =>
      state = state.copyWith(signature: strokes);

  Future<Inspection> submit({
    required Vehicle vehicle,
    required Inspector inspector,
    required ChecklistTemplate template,
  }) async {
    final errors = InspectionRules.validate(
      template: template,
      answers: state.answers,
      vehicle: vehicle,
      odometerKm: state.odometerKm,
      fuel: state.fuel,
      signed: state.signed,
    );
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));

    final saved = await ref
        .read(repositoryProvider)
        .submit(
          Inspection(
            id: '',
            vehicle: vehicle,
            inspector: inspector,
            templateId: template.id,
            templateVersion: template.version,
            answers: state.answers,
            odometerKm: state.odometerKm!,
            fuel: state.fuel!,
            verdict: InspectionRules.verdictFor(
              template,
              state.answers,
              state.damages,
            ),
            startedAt: state.startedAt,
            submittedAt: DateTime.now(),
            signature: state.signature,
            damages: state.damages,
          ),
        );
    ref
      ..invalidate(historyProvider)
      ..invalidate(vehiclesProvider)
      ..invalidateSelf();
    return saved;
  }
}

final draftProvider =
    NotifierProvider.family<DraftNotifier, InspectionDraft, String>(
      DraftNotifier.new,
    );
