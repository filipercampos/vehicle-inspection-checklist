import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import '../l10n/l10n.dart';
import 'theme.dart';

extension VerdictStyle on Verdict {
  Color color(ColorScheme scheme) => switch (this) {
    Verdict.approved => AppPalette.of(scheme.brightness).ok,
    Verdict.approvedWithRestrictions => AppPalette.of(scheme.brightness).warn,
    Verdict.blocked => AppPalette.of(scheme.brightness).bad,
  };

  IconData get icon => switch (this) {
    Verdict.approved => Icons.check_circle,
    Verdict.approvedWithRestrictions => Icons.warning_amber_rounded,
    Verdict.blocked => Icons.block,
  };

  String get shortLabel => switch (this) {
    Verdict.approved => 'Approved',
    Verdict.approvedWithRestrictions => 'Restricted',
    Verdict.blocked => 'Blocked',
  };
}

class VerdictChip extends StatelessWidget {
  const VerdictChip(this.verdict, {super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final color = verdict.color(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verdict.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            context.t(verdict.shortLabel),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class VerdictBanner extends StatelessWidget {
  const VerdictBanner(this.verdict, {super.key, this.subtitle});

  final Verdict verdict;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = verdict.color(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(verdict.icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(verdict.label),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                if (subtitle != null) Text(subtitle!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CriticalBadge extends StatelessWidget {
  const CriticalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.t('Critical item: a defect blocks the vehicle'),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          context.t('CRITICAL'),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: scheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

IconData vehicleIcon(VehicleType type) => switch (type) {
  VehicleType.car => Icons.directions_car,
  VehicleType.suv => Icons.directions_car_filled,
  VehicleType.pickup => Icons.local_shipping_outlined,
};

/// Shared error/loading rendering for AsyncValue-based screens.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
