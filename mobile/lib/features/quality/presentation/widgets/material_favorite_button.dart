import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../materials/domain/models/material_summary.dart';
import '../providers/favorite_action_provider.dart';

/// Control reutilizable para agregar y quitar un material de favoritos (Issue #418 - S3-M31).
///
/// - En modo [compact] (tarjetas), muestra el ícono de marcador (`bookmark_rounded` /
///   `bookmark_border_rounded`), progreso en vuelo y opción rápida de reintento ante error.
/// - En modo extendido (pantalla de detalle), muestra un botón con etiqueta del estado
///   confirmado (`"Guardado en favoritos"` / `"Guardar en favoritos"`) y un banner con
///   acción `"Reintentar"` si ocurre un fallo.
/// - Tolera árboles de prueba aislados sin `ProviderScope` sin lanzar excepciones.
class MaterialFavoriteButton extends StatelessWidget {
  final String materialId;
  final MaterialSummary? materialSummary;
  final bool compact;

  const MaterialFavoriteButton({
    super.key,
    required this.materialId,
    this.materialSummary,
    this.compact = true,
  });

  bool _hasProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (materialId.trim().isEmpty || !_hasProviderScope(context)) {
      return const SizedBox.shrink();
    }
    return _ConnectedMaterialFavoriteButton(
      materialId: materialId,
      materialSummary: materialSummary,
      compact: compact,
    );
  }
}

class _ConnectedMaterialFavoriteButton extends ConsumerWidget {
  final String materialId;
  final MaterialSummary? materialSummary;
  final bool compact;

  const _ConnectedMaterialFavoriteButton({
    required this.materialId,
    required this.materialSummary,
    required this.compact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteActionProvider(materialId));
    final notifier = ref.read(favoriteActionProvider(materialId).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.hasError)
            IconButton(
              key: ValueKey('favorite-retry-compact-$materialId'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Reintentar favorito: ${state.errorMessage}',
              onPressed: state.isPending ? null : () => notifier.retry(),
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: colorScheme.error,
              ),
            ),
          IconButton(
            key: ValueKey('favorite-toggle-compact-$materialId'),
            visualDensity: VisualDensity.compact,
            tooltip: state.isFavorite
                ? 'Quitar de favoritos'
                : 'Guardar en favoritos',
            onPressed: state.isPending
                ? null
                : () => notifier.toggleFavorite(summary: materialSummary),
            icon: state.isPending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    state.isFavorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: state.isFavorite
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          key: ValueKey('favorite-toggle-detail-$materialId'),
          onPressed: state.isPending
              ? null
              : () => notifier.toggleFavorite(summary: materialSummary),
          icon: state.isPending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  state.isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
          label: Text(
            state.isFavorite
                ? 'Guardado en favoritos'
                : 'Guardar en favoritos',
          ),
        ),
        if (state.hasError) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  key: ValueKey('favorite-retry-detail-$materialId'),
                  onPressed: state.isPending ? null : () => notifier.retry(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
