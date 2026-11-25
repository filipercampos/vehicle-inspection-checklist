import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Light vehicles only: heavy vehicles are out of scope.
enum VehicleType { car, suv, pickup }

extension VehicleTypeLabel on VehicleType {
  String get label => switch (this) {
    VehicleType.car => 'Car',
    VehicleType.suv => 'SUV',
    VehicleType.pickup => 'Pickup',
  };
}

@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.model,
    required this.type,
    required this.odometerKm,
    required this.depot,
  });

  final String id;
  final String plate;
  final String model;
  final VehicleType type;
  final int odometerKm;
  final String depot;

  Vehicle copyWith({int? odometerKm}) => Vehicle(
    id: id,
    plate: plate,
    model: model,
    type: type,
    odometerKm: odometerKm ?? this.odometerKm,
    depot: depot,
  );
}

@immutable
class Inspector {
  const Inspector({required this.id, required this.name, required this.depot});

  final String id;
  final String name;
  final String depot;
}

/// A single question in a checklist. Critical items block dispatch when they fail.
@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.label,
    this.critical = false,
    this.hint,
  });

  final String id;
  final String label;
  final bool critical;
  final String? hint;
}

@immutable
class ChecklistSection {
  const ChecklistSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<ChecklistItem> items;
}

/// Versioned template: completed inspections keep the version they were filled with.
@immutable
class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.sections,
  });

  final String id;
  final int version;
  final String name;
  final List<ChecklistSection> sections;

  Iterable<ChecklistItem> get allItems => sections.expand((s) => s.items);
}

enum ItemStatus { ok, defect, notApplicable }

@immutable
class ItemAnswer {
  const ItemAnswer({required this.status, this.note = ''});

  final ItemStatus status;
  final String note;

  ItemAnswer copyWith({ItemStatus? status, String? note}) =>
      ItemAnswer(status: status ?? this.status, note: note ?? this.note);
}

/// Body parts that can be selected on the 3D damage map.
enum CarPart {
  frontBumper('Front bumper'),
  hood('Hood'),
  windshield('Windshield', safety: true),
  roof('Roof'),
  rearWindow('Rear window'),
  tailgate('Tailgate'),

  /// Open bed of a pickup; other vehicle types have none.
  cargoBed('Cargo bed'),
  rearBumper('Rear bumper'),
  fenderFrontLeft('Front left fender'),
  fenderFrontRight('Front right fender'),
  doorFrontLeft('Front left door'),
  doorFrontRight('Front right door'),
  doorRearLeft('Rear left door'),
  doorRearRight('Rear right door'),
  quarterRearLeft('Rear left quarter panel'),
  quarterRearRight('Rear right quarter panel'),
  windowsLeft('Left side windows'),
  windowsRight('Right side windows'),
  wheelFrontLeft('Front left wheel', safety: true),
  wheelFrontRight('Front right wheel', safety: true),
  wheelRearLeft('Rear left wheel', safety: true),
  wheelRearRight('Rear right wheel', safety: true),
  headlightLeft('Left headlight', safety: true),
  headlightRight('Right headlight', safety: true),
  taillightLeft('Left taillight', safety: true),
  taillightRight('Right taillight', safety: true),
  mirrorLeft('Left mirror', safety: true),
  mirrorRight('Right mirror', safety: true);

  const CarPart(this.label, {this.safety = false});

  final String label;

  /// Safety parts: a broken/missing one blocks the vehicle.
  final bool safety;
}

enum DamageType { scratch, dent, broken, missing }

extension DamageTypeLabel on DamageType {
  String get label => switch (this) {
    DamageType.scratch => 'Scratch',
    DamageType.dent => 'Dent',
    DamageType.broken => 'Broken / cracked',
    DamageType.missing => 'Missing',
  };

  /// Structural damage, as opposed to cosmetic.
  bool get severe => this == DamageType.broken || this == DamageType.missing;
}

@immutable
class DamageMark {
  const DamageMark({required this.part, required this.type, this.note = ''});

  final CarPart part;
  final DamageType type;
  final String note;

  bool get blocking => part.safety && type.severe;
}

enum Verdict { approved, approvedWithRestrictions, blocked }

extension VerdictLabel on Verdict {
  String get label => switch (this) {
    Verdict.approved => 'Approved',
    Verdict.approvedWithRestrictions => 'Approved with restrictions',
    Verdict.blocked => 'Blocked — do not dispatch',
  };
}

enum FuelLevel { empty, quarter, half, threeQuarters, full }

extension FuelLevelLabel on FuelLevel {
  String get label => switch (this) {
    FuelLevel.empty => 'Empty',
    FuelLevel.quarter => '1/4',
    FuelLevel.half => '1/2',
    FuelLevel.threeQuarters => '3/4',
    FuelLevel.full => 'Full',
  };
}

/// A submitted, immutable inspection record.
@immutable
class Inspection {
  const Inspection({
    required this.id,
    required this.vehicle,
    required this.inspector,
    required this.templateId,
    required this.templateVersion,
    required this.answers,
    required this.odometerKm,
    required this.fuel,
    required this.verdict,
    required this.startedAt,
    required this.submittedAt,
    required this.signature,
    this.damages = const {},
  });

  final String id;
  final Vehicle vehicle;
  final Inspector inspector;
  final String templateId;
  final int templateVersion;
  final Map<String, ItemAnswer> answers;
  final int odometerKm;
  final FuelLevel fuel;
  final Verdict verdict;
  final DateTime startedAt;
  final DateTime submittedAt;

  /// Body damage recorded on the 3D map, at most one mark per part.
  final Map<CarPart, DamageMark> damages;

  /// Signature strokes in normalized coordinates (0..1), kept vector to stay small.
  final List<List<Offset>> signature;

  int get defectCount =>
      answers.values.where((a) => a.status == ItemStatus.defect).length +
      damages.length;
}
