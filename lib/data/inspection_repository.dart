import '../domain/models.dart';
import 'mock_data.dart';

/// Port for persistence. The app only depends on this interface, so an HTTP
/// implementation can replace the in-memory one without touching the UI.
abstract interface class InspectionRepository {
  Future<List<Inspector>> inspectors();
  Future<List<Vehicle>> vehicles();
  Future<ChecklistTemplate> templateFor(VehicleType type);
  Future<List<Inspection>> history();
  Future<Inspection> submit(Inspection inspection);
}

class InMemoryInspectionRepository implements InspectionRepository {
  InMemoryInspectionRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now {
    _vehicles = {for (final v in MockData.vehicles) v.id: v};
    _history = MockData.seedHistory(_clock());
  }

  final DateTime Function() _clock;

  /// Simulated network latency so loading states are visible in the demo.
  final Duration latency;

  late final Map<String, Vehicle> _vehicles;
  late final List<Inspection> _history;
  int _seq = 1004;

  Future<T> _delay<T>(T Function() fn) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return fn();
  }

  @override
  Future<List<Inspector>> inspectors() => _delay(() => MockData.inspectors);

  @override
  Future<List<Vehicle>> vehicles() => _delay(() => _vehicles.values.toList());

  @override
  Future<ChecklistTemplate> templateFor(VehicleType type) =>
      _delay(() => MockData.templates[type]!);

  @override
  Future<List<Inspection>> history() => _delay(() {
    final list = [..._history]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  });

  @override
  Future<Inspection> submit(Inspection inspection) => _delay(() {
    final stored = Inspection(
      id: 'INS-${_seq++}',
      vehicle: inspection.vehicle,
      inspector: inspection.inspector,
      templateId: inspection.templateId,
      templateVersion: inspection.templateVersion,
      answers: Map.unmodifiable(inspection.answers),
      odometerKm: inspection.odometerKm,
      fuel: inspection.fuel,
      verdict: inspection.verdict,
      startedAt: inspection.startedAt,
      submittedAt: _clock(),
      signature: inspection.signature,
      damages: Map.unmodifiable(inspection.damages),
    );
    _history.add(stored);
    // The last reading becomes the new floor for the next inspection.
    _vehicles[inspection.vehicle.id] = inspection.vehicle.copyWith(
      odometerKm: inspection.odometerKm,
    );
    return stored;
  });
}
