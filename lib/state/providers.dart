import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inspection_repository.dart';
import '../domain/models.dart';

final repositoryProvider = Provider<InspectionRepository>(
  (ref) => InMemoryInspectionRepository(),
);

/// Logged-in inspector (mock auth: pick a profile, no password).
class SessionNotifier extends Notifier<Inspector?> {
  @override
  Inspector? build() => null;

  void signIn(Inspector inspector) => state = inspector;
  void signOut() => state = null;
}

final sessionProvider = NotifierProvider<SessionNotifier, Inspector?>(
  SessionNotifier.new,
);

final inspectorsProvider = FutureProvider<List<Inspector>>(
  (ref) => ref.watch(repositoryProvider).inspectors(),
);

final vehiclesProvider = FutureProvider<List<Vehicle>>(
  (ref) => ref.watch(repositoryProvider).vehicles(),
);

final historyProvider = FutureProvider<List<Inspection>>(
  (ref) => ref.watch(repositoryProvider).history(),
);

final templateProvider = FutureProvider.family<ChecklistTemplate, VehicleType>(
  (ref, type) => ref.watch(repositoryProvider).templateFor(type),
);

final vehicleByIdProvider = FutureProvider.family<Vehicle, String>((
  ref,
  id,
) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  return vehicles.firstWhere((v) => v.id == id);
});

final inspectionByIdProvider = FutureProvider.family<Inspection, String>((
  ref,
  id,
) async {
  final history = await ref.watch(historyProvider.future);
  return history.firstWhere((i) => i.id == id);
});

/// Latest inspection per vehicle, used for the fleet status badges.
final latestByVehicleProvider = FutureProvider<Map<String, Inspection>>((
  ref,
) async {
  final history = await ref.watch(historyProvider.future);
  final latest = <String, Inspection>{};
  for (final i in history) {
    latest.putIfAbsent(i.vehicle.id, () => i);
  }
  return latest;
});
