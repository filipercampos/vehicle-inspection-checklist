import 'models.dart';

/// Pure business rules for an inspection. No Flutter widgets, fully unit-testable.
class InspectionRules {
  const InspectionRules._();

  /// Any failed critical item or broken/missing safety part blocks the vehicle;
  /// any other defect or body damage restricts it.
  static Verdict verdictFor(
    ChecklistTemplate template,
    Map<String, ItemAnswer> answers, [
    Map<CarPart, DamageMark> damages = const {},
  ]) {
    if (damages.values.any((d) => d.blocking)) return Verdict.blocked;
    var hasDefect = damages.isNotEmpty;
    for (final item in template.allItems) {
      if (answers[item.id]?.status != ItemStatus.defect) continue;
      if (item.critical) return Verdict.blocked;
      hasDefect = true;
    }
    return hasDefect ? Verdict.approvedWithRestrictions : Verdict.approved;
  }

  /// Returns human-readable reasons why the inspection cannot be submitted yet.
  static List<String> validate({
    required ChecklistTemplate template,
    required Map<String, ItemAnswer> answers,
    required Vehicle vehicle,
    required int? odometerKm,
    required FuelLevel? fuel,
    required bool signed,
  }) {
    return [
      ...itemErrors(template.allItems, answers),
      ...readingErrors(vehicle: vehicle, odometerKm: odometerKm, fuel: fuel),
      if (!signed) 'Inspector signature is required',
    ];
  }

  /// Errors for one wizard step: a checklist section.
  static List<String> sectionErrors(
    ChecklistSection section,
    Map<String, ItemAnswer> answers,
  ) => itemErrors(section.items, answers);

  static List<String> itemErrors(
    Iterable<ChecklistItem> items,
    Map<String, ItemAnswer> answers,
  ) {
    final errors = <String>[];
    final unanswered = items.where((i) => !answers.containsKey(i.id)).length;
    if (unanswered > 0) {
      errors.add('$unanswered item(s) not answered');
    }

    final missingNotes = items.where((i) {
      final a = answers[i.id];
      return a != null &&
          a.status == ItemStatus.defect &&
          a.note.trim().isEmpty;
    }).length;
    if (missingNotes > 0) {
      errors.add('$missingNotes defect(s) without a description');
    }

    final criticalNa = items.where(
      (i) => i.critical && answers[i.id]?.status == ItemStatus.notApplicable,
    );
    if (criticalNa.isNotEmpty) {
      errors.add(
        'Critical items cannot be N/A: '
        '${criticalNa.map((i) => i.label).join(', ')}',
      );
    }
    return errors;
  }

  /// Errors for the readings step (odometer and fuel).
  static List<String> readingErrors({
    required Vehicle vehicle,
    required int? odometerKm,
    required FuelLevel? fuel,
  }) {
    final errors = <String>[];
    if (odometerKm == null) {
      errors.add('Odometer reading is required');
    } else if (odometerKm < vehicle.odometerKm) {
      errors.add(
        'Odometer cannot be lower than last reading '
        '(${vehicle.odometerKm} km)',
      );
    }

    if (fuel == null) errors.add('Fuel level is required');
    return errors;
  }

  /// Fraction of items answered, for progress indicators.
  static double progress(
    ChecklistTemplate template,
    Map<String, ItemAnswer> answers,
  ) {
    final total = template.allItems.length;
    if (total == 0) return 1;
    final done = template.allItems
        .where((i) => answers.containsKey(i.id))
        .length;
    return done / total;
  }
}
