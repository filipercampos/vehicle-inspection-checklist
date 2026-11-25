import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_inspection/data/inspection_repository.dart';
import 'package:vehicle_inspection/domain/models.dart';

void main() {
  late InMemoryInspectionRepository repo;
  final now = DateTime(2026, 11, 24, 10);

  setUp(
    () => repo = InMemoryInspectionRepository(
      clock: () => now,
      latency: Duration.zero,
    ),
  );

  test('seed history is sorted newest first', () async {
    final history = await repo.history();
    expect(history, isNotEmpty);
    for (var i = 1; i < history.length; i++) {
      expect(
        history[i - 1].submittedAt.isAfter(history[i].submittedAt),
        isTrue,
      );
    }
  });

  test(
    'submit assigns id, timestamps it and updates vehicle odometer',
    () async {
      final vehicle = (await repo.vehicles()).first;
      final inspector = (await repo.inspectors()).first;
      final template = await repo.templateFor(vehicle.type);

      final saved = await repo.submit(
        Inspection(
          id: '',
          vehicle: vehicle,
          inspector: inspector,
          templateId: template.id,
          templateVersion: template.version,
          answers: {
            for (final i in template.allItems)
              i.id: const ItemAnswer(status: ItemStatus.ok),
          },
          odometerKm: vehicle.odometerKm + 120,
          fuel: FuelLevel.full,
          verdict: Verdict.approved,
          startedAt: now.subtract(const Duration(minutes: 5)),
          submittedAt: now,
          signature: const [],
        ),
      );

      expect(saved.id, startsWith('INS-'));
      expect(saved.submittedAt, now);
      expect((await repo.history()).first.id, saved.id);
      final updated = (await repo.vehicles()).firstWhere(
        (v) => v.id == vehicle.id,
      );
      expect(updated.odometerKm, vehicle.odometerKm + 120);
    },
  );
}
