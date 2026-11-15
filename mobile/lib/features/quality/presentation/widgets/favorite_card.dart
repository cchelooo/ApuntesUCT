import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../materials/presentation/screens/material_detail_screen.dart';
import '../../../materials/presentation/widgets/material_summary_card.dart';
import '../../domain/models/favorite_item.dart';

/// Tarjeta para un material guardado en favoritos.
///
/// Reutiliza [MaterialSummaryCard] existente (Criterio 2) y gestiona la
/// navegación segura hacia el detalle mediante el ID del material.
class FavoriteCard extends StatelessWidget {
  final FavoriteItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const FavoriteCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRemove,
  });

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }

    try {
      GoRouter.of(context).push('/materials/${item.materialId}');
      return;
    } catch (_) {
      // Fallback para pruebas unitarias sin GoRouter
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialDetailScreen.byId(
          materialId: item.materialId,
          initialSummary: item.toMaterialSummary(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        MaterialSummaryCard(
          material: item.toMaterialSummary(),
          onTap: () => _handleTap(context),
        ),
        if (!item.available)
          Positioned(
            bottom: 12,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'No disponible',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
