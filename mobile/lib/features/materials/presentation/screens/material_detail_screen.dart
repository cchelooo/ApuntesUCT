import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_detail_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaterialDetailScreen extends ConsumerWidget {
  final MaterialDetail? _detail;
  final String? materialId;

  const MaterialDetailScreen({super.key, required MaterialDetail detail})
    : _detail = detail, // ignore: prefer_initializing_formals
      materialId = null;

  const MaterialDetailScreen.byId({super.key, required this.materialId})
    : _detail = null;

  MaterialDetail get detail => _detail!;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_detail != null) {
      return _buildScaffold(context, _detail);
    }

    final detailAsync = ref.watch(materialDetailProvider(materialId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Material'),
        centerTitle: true,
      ),
      body: detailAsync.when(
        loading: () =>
            const LoadingState(message: 'Cargando información del material...'),
        error: (error, _) {
          if (error.isNotFound) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      title: 'Material no encontrado',
                      subtitle: 'El material solicitado no existe o fue eliminado del catálogo.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver al catálogo'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ErrorState(
                message:
                    'No fue posible cargar el material. Verifica tu conexión.',
                onRetry: () =>
                    ref.invalidate(materialDetailProvider(materialId!)),
              ),
            ),
          );
        },
        data: (loadedDetail) => _buildBody(context, loadedDetail),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, MaterialDetail data) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Material'),
        centerTitle: true,
      ),
      body: _buildBody(context, data),
    );
  }

  Widget _buildBody(BuildContext context, MaterialDetail data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = data.summary;
    final currentVersion = data.currentVersion;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.subjectName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  summary.academicYear != null
                      ? '${summary.academicYear}'
                      : 'Sin año',
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(summary.materialType.toUpperCase()),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              Builder(
                builder: (context) {
                  final s = summary.status.trim().toUpperCase();
                  final isPending = s == 'PENDING_REVIEW' || s == 'EN REVISIÓN';
                  final isApproved = s == 'APROBADO' || s == 'APPROVED';
                  final label = isPending
                      ? 'EN REVISIÓN'
                      : (isApproved ? 'APROBADO' : s);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isApproved
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Subido por ${summary.authorName} • ${summary.careerName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
          if (summary.professor != null && summary.professor!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Docente: ${summary.professor}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (currentVersion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Versión actual: v${currentVersion.versionNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (currentVersion.originalFileName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${currentVersion.originalFileName})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const Divider(height: 32),
          Text(
            'Descripción',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.description.isNotEmpty
                ? summary.description
                : 'Sin descripción proporcionada.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (data.tags.isNotEmpty) ...[
            Text(
              'Etiquetas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(
                      'Descargas',
                      '${summary.downloadCount}',
                      Icons.download,
                      colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      'Calificación',
                      summary.rating.toStringAsFixed(1),
                      Icons.star,
                      Colors.amber.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      'Tamaño',
                      _formatBytes(
                        currentVersion?.fileSizeBytes ?? data.fileSizeBytes,
                      ),
                      Icons.folder_zip,
                      colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar Material'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
