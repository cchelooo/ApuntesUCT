import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:flutter/material.dart';

class MaterialSummaryCard extends StatelessWidget {
  final MaterialSummary material;
  final VoidCallback? onTap;

  const MaterialSummaryCard({super.key, required this.material, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 4),
                        Text(
                          '${material.subjectName} • ${material.careerName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (material.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  material.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    material.authorName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    material.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${material.downloadCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
