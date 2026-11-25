import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/providers.dart';
import '../ui/app_drawer.dart';
import '../ui/widgets.dart';

class FleetPage extends ConsumerStatefulWidget {
  const FleetPage({super.key});

  @override
  ConsumerState<FleetPage> createState() => _FleetPageState();
}

class _FleetPageState extends ConsumerState<FleetPage> {
  String _query = '';
  VehicleType? _type;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final latest = ref.watch(latestByVehicleProvider).value ?? const {};
    final km = NumberFormat.decimalPattern('pt_BR');

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(context.t('Fleet')),
      ),
      body: vehicles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenteredMessage(
          context.t('Failed to load fleet: {error}', {'error': e}),
        ),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final list = all.where((v) {
            if (_type != null && v.type != _type) return false;
            if (q.isEmpty) return true;
            return v.plate.toLowerCase().contains(q) ||
                v.model.toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.t('Search plate or model'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.t('All')),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  for (final t in VehicleType.values)
                    ChoiceChip(
                      avatar: Icon(vehicleIcon(t), size: 16),
                      label: Text(context.t(t.label)),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                CenteredMessage(context.t('No vehicles match the filter.')),
              for (final v in list)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(vehicleIcon(v.type))),
                    title: Text(
                      v.plate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    subtitle: Text(
                      '${v.model}\n${km.format(v.odometerKm)} km · ${v.depot}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (latest[v.id] case final last?)
                          VerdictChip(last.verdict)
                        else
                          Text(
                            context.t('Never inspected'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          context.t('Inspect ›'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/inspect/${v.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
