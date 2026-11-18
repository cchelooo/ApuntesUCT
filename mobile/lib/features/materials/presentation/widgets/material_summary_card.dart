import 'material_publication_badges.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(
                    label: Text(
                      material.materialType.isEmpty
                          ? 'SIN TIPO'
                          : material.materialType.toUpperCase(),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(material.academicYear?.toString() ?? 'Sin año'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MaterialPublicationBadges(material: material),
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
                        // Mostrar asignatura y carrera solo si están disponibles y no son genéricas vacías
                        if ((material.subjectName.isNotEmpty &&
                                material.subjectName != 'General') ||
                            (material.careerName.isNotEmpty &&
                                material.careerName != 'UCT')) ...[
                          Text(
                            [
                              if (material.subjectName.isNotEmpty &&
                                  material.subjectName != 'General')
                                material.subjectName,
                              if (material.careerName.isNotEmpty &&
                                  material.careerName != 'UCT')
                                material.careerName,
                            ].join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
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
