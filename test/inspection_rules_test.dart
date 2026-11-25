import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_inspection/data/mock_data.dart';
import 'package:vehicle_inspection/domain/inspection_rules.dart';
import 'package:vehicle_inspection/domain/models.dart';

void main() {
  final template = MockData.templates[VehicleType.car]!;
  final vehicle = MockData.vehicles.firstWhere(
    (v) => v.type == VehicleType.car,
  );

  Map<String, ItemAnswer> allOk() => {
    for (final i in template.allItems)
      i.id: const ItemAnswer(status: ItemStatus.ok),
  };

  final critical = template.allItems.firstWhere((i) => i.critical);
  final minor = template.allItems.firstWhere((i) => !i.critical);

  group('verdictFor', () {
    test('all OK is approved', () {
      expect(InspectionRules.verdictFor(template, allOk()), Verdict.approved);
    });

    test('non-critical defect restricts the vehicle', () {
      final answers = allOk()
        ..[minor.id] = const ItemAnswer(status: ItemStatus.defect, note: 'x');
      expect(
        InspectionRules.verdictFor(template, answers),
        Verdict.approvedWithRestrictions,
      );
    });

    test('critical defect blocks regardless of other answers', () {
      final answers = allOk()
        ..[minor.id] = const ItemAnswer(status: ItemStatus.defect, note: 'x')
        ..[critical.id] = const ItemAnswer(
          status: ItemStatus.defect,
          note: 'y',
        );
      expect(InspectionRules.verdictFor(template, answers), Verdict.blocked);
    });

    test('N/A on non-critical item does not affect verdict', () {
      final answers = allOk()
        ..[minor.id] = const ItemAnswer(status: ItemStatus.notApplicable);
      expect(InspectionRules.verdictFor(template, answers), Verdict.approved);
    });
  });

  group('validate', () {
    List<String> run(
      Map<String, ItemAnswer> answers, {
      int? odometer,
      FuelLevel? fuel = FuelLevel.half,
      bool signed = true,
    }) => InspectionRules.validate(
      template: template,
      answers: answers,
      vehicle: vehicle,
      odometerKm: odometer ?? vehicle.odometerKm + 10,
      fuel: fuel,
      signed: signed,
    );

    test('complete inspection has no errors', () {
      expect(run(allOk()), isEmpty);
    });

    test('reports unanswered items', () {
      final answers = allOk()..remove(minor.id);
      expect(run(answers), contains('1 item(s) not answered'));
    });

    test('defect requires a description', () {
      final answers = allOk()
        ..[minor.id] = const ItemAnswer(status: ItemStatus.defect);
      expect(run(answers), contains('1 defect(s) without a description'));
    });

    test('critical item cannot be N/A', () {
      final answers = allOk()
        ..[critical.id] = const ItemAnswer(status: ItemStatus.notApplicable);
      expect(run(answers).single, startsWith('Critical items cannot be N/A'));
    });

    test('odometer cannot go backwards', () {
      final errors = run(allOk(), odometer: vehicle.odometerKm - 1);
      expect(errors.single, startsWith('Odometer cannot be lower'));
    });

    test('fuel and signature are required', () {
      expect(run(allOk(), fuel: null, signed: false), [
        'Fuel level is required',
        'Inspector signature is required',
      ]);
    });
  });

  test('progress counts answered items', () {
    final total = template.allItems.length;
    final answers = {
      template.allItems.first.id: const ItemAnswer(status: ItemStatus.ok),
    };
    expect(InspectionRules.progress(template, answers), 1 / total);
  });

  group('body damage', () {
    test('cosmetic damage restricts the vehicle', () {
      final damages = {
        CarPart.hood: const DamageMark(
          part: CarPart.hood,
          type: DamageType.dent,
        ),
      };
      expect(
        InspectionRules.verdictFor(template, allOk(), damages),
        Verdict.approvedWithRestrictions,
      );
    });

    test('broken safety part blocks the vehicle', () {
      final damages = {
        CarPart.windshield: const DamageMark(
          part: CarPart.windshield,
          type: DamageType.broken,
        ),
      };
      expect(
        InspectionRules.verdictFor(template, allOk(), damages),
        Verdict.blocked,
      );
    });

    test('scratch on a safety part only restricts', () {
      final damages = {
        CarPart.mirrorLeft: const DamageMark(
          part: CarPart.mirrorLeft,
          type: DamageType.scratch,
        ),
      };
      expect(
        InspectionRules.verdictFor(template, allOk(), damages),
        Verdict.approvedWithRestrictions,
      );
    });
  });
}
