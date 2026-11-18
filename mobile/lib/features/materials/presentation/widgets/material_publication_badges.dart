import 'package:flutter/material.dart';

import '../../domain/models/material_status.dart';
import '../../domain/models/material_summary.dart';

/// Publication and verification are independent facts from the response.
class MaterialPublicationBadges extends StatelessWidget {
  const MaterialPublicationBadges({super.key, required this.material});
  final MaterialSummary material;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = material.reviewStatus;
    final (background, foreground) = switch (state) {
      MaterialStatus.published => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      MaterialStatus.pendingReview => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      MaterialStatus.rejected || MaterialStatus.withdrawn => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    Widget badge(
      String label,
      Color bg,
      Color fg, {
      Key? key,
      IconData? icon,
    }) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        badge(
          state.label.toUpperCase(),
          background,
          foreground,
          key: const Key('material_status_badge'),
        ),
        badge(
          material.verified ? 'Verificado' : 'Sin verificación',
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
          key: const Key('material_verification_badge'),
          icon: material.verified
              ? Icons.verified_outlined
              : Icons.help_outline,
        ),
      ],
    );
  }
}
