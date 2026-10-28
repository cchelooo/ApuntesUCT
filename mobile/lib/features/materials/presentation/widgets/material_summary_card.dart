import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MaterialSummaryCard extends StatelessWidget {
  final MaterialSummary material;
  final VoidCallback? onTap;

  const MaterialSummaryCard({super.key, required this.material, this.onTap});

  void _defaultNavigate(BuildContext context) {
    try {
      GoRouter.of(context).push('/materials/${material.id}');
      return;
    } catch (_) {
      // Sin GoRouter disponible (tests unitarios/aislados): fallback legacy
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialDetailScreen.byId(
          materialId: material.id,
          initialSummary: material,
        ),
      ),
    );
  }

  /// Configuración de color accesible según el estado del material y el brillo del tema.
  (Color background, Color foreground) _statusColors(
    MaterialStatus status,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    switch (status) {
      case MaterialStatus.published:
      case MaterialStatus.approved:
        return isDark
            ? (
                Colors.green.shade900.withValues(alpha: 0.4),
                Colors.green.shade200,
              )
            : (Colors.green.shade100, Colors.green.shade900);
      case MaterialStatus.pendingReview:
        return isDark
            ? (
                Colors.amber.shade900.withValues(alpha: 0.4),
                Colors.amber.shade200,
              )
            : (Colors.amber.shade100, Colors.amber.shade900);
      case MaterialStatus.rejected:
      case MaterialStatus.withdrawn:
        return isDark
            ? (
                colorScheme.errorContainer.withValues(alpha: 0.4),
                colorScheme.onErrorContainer,
              )
            : (colorScheme.errorContainer, colorScheme.onErrorContainer);
      case MaterialStatus.unknown:
        return (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (statusBg, statusFg) = _statusColors(
      material.reviewStatus,
      colorScheme,
      isDark,
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => _defaultNavigate(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Tipo, Año académico y Badge de Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            material.materialType.isEmpty
                                ? 'SIN TIPO'
                                : material.materialType.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            material.academicYear?.toString() ?? 'Sin año',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge de estado con semántica clara
                  Container(
                    key: const Key('material_status_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      material.reviewStatus.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Cuerpo: Ícono y Detalles del Contrato
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: colorScheme.onSecondaryContainer,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${material.subjectName} • ${material.careerName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (material.professor != null &&
                            material.professor!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 13,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  material.professor!.startsWith('Prof.')
                                      ? material.professor!
                                      : 'Prof. ${material.professor}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (material.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  material.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              // Fila inferior: Autor y Metadatos de interacción
              // Fila inferior: Autor y Metadatos de interacción
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      material.authorName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // OCULTAR RATING: Si es 0 o no hay valor real, no se muestra para evitar datos ficticios
                  if (material.rating > 0) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: isDark
                          ? Colors.amber.shade300
                          : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      material.rating.toStringAsFixed(1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  // OCULTAR DESCARGAS: Si el contador es 0 o no está disponible, se omite por completo
                  if (material.downloadCount > 0) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.download_rounded,
                      size: 14,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${material.downloadCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
