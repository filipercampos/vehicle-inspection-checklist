import 'dart:ui' show Offset;

import '../domain/models.dart';

/// Seed data. Everything lives in memory: no backend, no API keys.
class MockData {
  const MockData._();

  static const inspectors = [
    Inspector(id: 'u1', name: 'Ana Souza', depot: 'São Paulo — Mooca'),
    Inspector(id: 'u2', name: 'Bruno Lima', depot: 'Campinas'),
    Inspector(id: 'u3', name: 'Carla Mendes', depot: 'São Paulo — Mooca'),
  ];

  static const vehicles = [
    Vehicle(
      id: 'v1',
      plate: 'RTA-4F21',
      model: 'Jeep Compass Longitude',
      type: VehicleType.suv,
      odometerKm: 58340,
      depot: 'São Paulo — Mooca',
    ),
    Vehicle(
      id: 'v2',
      plate: 'QXZ-8B03',
      model: 'Hyundai Creta Limited',
      type: VehicleType.suv,
      odometerKm: 36412,
      depot: 'São Paulo — Mooca',
    ),
    Vehicle(
      id: 'v3',
      plate: 'SBK-1C77',
      model: 'Fiat Strada Freedom',
      type: VehicleType.pickup,
      odometerKm: 41208,
      depot: 'Campinas',
    ),
    Vehicle(
      id: 'v4',
      plate: 'PLM-6D90',
      model: 'VW T-Cross Highline',
      type: VehicleType.suv,
      odometerKm: 72982,
      depot: 'Campinas',
    ),
    Vehicle(
      id: 'v5',
      plate: 'RJU-2E15',
      model: 'VW Polo Highline',
      type: VehicleType.car,
      odometerKm: 123550,
      depot: 'São Paulo — Mooca',
    ),
    Vehicle(
      id: 'v6',
      plate: 'TGH-9A42',
      model: 'Chevrolet Onix LT',
      type: VehicleType.car,
      odometerKm: 18730,
      depot: 'São Paulo — Mooca',
    ),
  ];

  static const _exterior = ChecklistSection(
    id: 'exterior',
    title: 'Exterior',
    items: [
      ChecklistItem(
        id: 'ext.mirrors',
        label: 'Mirrors intact and adjusted',
        critical: true,
      ),
      ChecklistItem(
        id: 'ext.windshield',
        label: 'Windshield without cracks in driver view',
        critical: true,
      ),
      ChecklistItem(id: 'ext.wipers', label: 'Wipers and washer fluid working'),
      ChecklistItem(id: 'ext.plates', label: 'License plates readable'),
    ],
  );

  static const _tires = ChecklistSection(
    id: 'tires',
    title: 'Tires & wheels',
    items: [
      ChecklistItem(
        id: 'tir.tread',
        label: 'Tread depth above 1.6 mm',
        critical: true,
        hint: 'Use the TWI wear indicator',
      ),
      ChecklistItem(id: 'tir.pressure', label: 'Pressure visually correct'),
      ChecklistItem(
        id: 'tir.nuts',
        label: 'Wheel nuts present and tight',
        critical: true,
      ),
      ChecklistItem(
        id: 'tir.spare',
        label: 'Spare tire, jack and wrench on board',
      ),
    ],
  );

  static const _lights = ChecklistSection(
    id: 'lights',
    title: 'Lights & signals',
    items: [
      ChecklistItem(
        id: 'lig.head',
        label: 'Headlights (low and high beam)',
        critical: true,
      ),
      ChecklistItem(id: 'lig.brake', label: 'Brake lights', critical: true),
      ChecklistItem(
        id: 'lig.turn',
        label: 'Turn signals and hazard lights',
        critical: true,
      ),
      ChecklistItem(id: 'lig.reverse', label: 'Reverse light and alarm'),
      ChecklistItem(id: 'lig.dash', label: 'No warning lights on dashboard'),
    ],
  );

  static const _brakes = ChecklistSection(
    id: 'brakes',
    title: 'Brakes & steering',
    items: [
      ChecklistItem(
        id: 'brk.service',
        label: 'Service brake firm, no pulling',
        critical: true,
      ),
      ChecklistItem(
        id: 'brk.parking',
        label: 'Parking brake holds on slope',
        critical: true,
      ),
      ChecklistItem(
        id: 'brk.steering',
        label: 'Steering without excessive play',
        critical: true,
      ),
      ChecklistItem(id: 'brk.horn', label: 'Horn working'),
    ],
  );

  static const _fluids = ChecklistSection(
    id: 'fluids',
    title: 'Fluids & engine',
    items: [
      ChecklistItem(id: 'flu.oil', label: 'Engine oil between MIN and MAX'),
      ChecklistItem(id: 'flu.coolant', label: 'Coolant level OK'),
      ChecklistItem(
        id: 'flu.leaks',
        label: 'No leaks under the vehicle',
        critical: true,
      ),
    ],
  );

  static const _safety = ChecklistSection(
    id: 'safety',
    title: 'Safety & documents',
    items: [
      ChecklistItem(
        id: 'saf.belts',
        label: 'Seat belts latch and retract',
        critical: true,
      ),
      ChecklistItem(
        id: 'saf.triangle',
        label: 'Warning triangle on board',
        critical: true,
      ),
      ChecklistItem(
        id: 'saf.extinguisher',
        label: 'Fire extinguisher charged and in date',
      ),
      ChecklistItem(
        id: 'saf.crlv',
        label: 'Vehicle registration (CRLV) on board',
      ),
    ],
  );

  static const _sections = [
    _exterior,
    _tires,
    _lights,
    _brakes,
    _fluids,
    _safety,
  ];

  static const templates = {
    VehicleType.car: ChecklistTemplate(
      id: 'tpl-car',
      version: 3,
      name: 'Light vehicle pre-trip',
      sections: _sections,
    ),
    VehicleType.suv: ChecklistTemplate(
      id: 'tpl-suv',
      version: 2,
      name: 'SUV pre-trip',
      sections: _sections,
    ),
    VehicleType.pickup: ChecklistTemplate(
      id: 'tpl-pickup',
      version: 2,
      name: 'Pickup pre-trip',
      sections: _sections,
    ),
  };

  /// A few past inspections so history and dashboard are not empty on first run.
  static List<Inspection> seedHistory(DateTime now) {
    Map<String, ItemAnswer> allOk(ChecklistTemplate t) => {
      for (final i in t.allItems) i.id: const ItemAnswer(status: ItemStatus.ok),
    };

    final suv = templates[VehicleType.suv]!;
    final pickup = templates[VehicleType.pickup]!;

    Inspection build(
      String id,
      Vehicle v,
      Inspector who,
      ChecklistTemplate t,
      Map<String, ItemAnswer> answers,
      Verdict verdict,
      Duration ago, {
      Map<CarPart, DamageMark> damages = const {},
    }) {
      final submitted = now.subtract(ago);
      return Inspection(
        id: id,
        vehicle: v,
        inspector: who,
        templateId: t.id,
        templateVersion: t.version,
        answers: answers,
        odometerKm: v.odometerKm,
        fuel: FuelLevel.threeQuarters,
        verdict: verdict,
        startedAt: submitted.subtract(const Duration(minutes: 9)),
        submittedAt: submitted,
        signature: _demoSignature,
        damages: damages,
      );
    }

    return [
      build(
        'INS-1003',
        vehicles[3],
        inspectors[1],
        suv,
        {
          ...allOk(suv),
          'brk.parking': const ItemAnswer(
            status: ItemStatus.defect,
            note: 'Does not hold on depot ramp',
          ),
        },
        Verdict.blocked,
        const Duration(hours: 3),
      ),
      build(
        'INS-1002',
        vehicles[1],
        inspectors[0],
        suv,
        allOk(suv),
        Verdict.approvedWithRestrictions,
        const Duration(hours: 20),
        damages: const {
          CarPart.doorRearRight: DamageMark(
            part: CarPart.doorRearRight,
            type: DamageType.scratch,
            note: '15 cm scratch near the handle',
          ),
          CarPart.frontBumper: DamageMark(
            part: CarPart.frontBumper,
            type: DamageType.dent,
          ),
        },
      ),
      build(
        'INS-1001',
        vehicles[2],
        inspectors[1],
        pickup,
        allOk(pickup),
        Verdict.approved,
        const Duration(days: 1, hours: 4),
      ),
    ];
  }

  static final _demoSignature = [
    [
      for (var x = 0; x <= 20; x++)
        Offset(0.1 + x * 0.03, 0.5 + 0.2 * ((x % 4) - 1.5) / 1.5),
    ],
  ];
}
