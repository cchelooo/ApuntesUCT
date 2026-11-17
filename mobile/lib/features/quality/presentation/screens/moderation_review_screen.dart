import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../materials/data/material_file_handler.dart';
import '../../../materials/domain/models/material_version.dart';
import '../../domain/models/moderation_material_detail.dart';
import '../providers/moderation_review_provider.dart';

/// Vista de solo lectura de moderación para inspeccionar un material pendiente (#410).
class ModerationReviewScreen extends ConsumerStatefulWidget {
  final ModerationMaterialDetail detail;

  const ModerationReviewScreen({super.key, required this.detail});

  @override
  ConsumerState<ModerationReviewScreen> createState() =>
      _ModerationReviewScreenState();
}

class _ModerationReviewScreenState
    extends ConsumerState<ModerationReviewScreen> {
  bool _openingFile = false;
  String? _busyVersionId;
  String? _actionError;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    if (error is MaterialFileException) return error.message;
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        403 => 'No tienes autorización para descargar este material.',
        404 => 'El archivo pendiente ya no está disponible en Quality.',
        502 || 503 => 'El servicio de moderación no está disponible.',
        _ => error.message,
      };
    }
    return 'No se pudo procesar el recurso del material.';
  }

  Future<void> _downloadFile({String? versionId}) async {
    setState(() {
      _actionError = null;
      _busyVersionId = versionId;
    });
    try {
      final result = await ref
          .read(moderationMaterialDownloadProvider.notifier)
          .download(widget.detail.materialId, versionId: versionId);
      if (!mounted || result == null) return;
      _showSnackBar('Archivo listo para revisión: ${result.download.fileName}');
    } catch (error) {
      if (mounted) setState(() => _actionError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyVersionId = null);
    }
  }

  Future<void> _openDownloadedFile(ModerationDownloadResult result) async {
    if (_openingFile) return;
    setState(() {
      _openingFile = true;
      _actionError = null;
    });
    try {
      await ref
          .read(moderationMaterialDownloadProvider.notifier)
          .openSavedFile(result);
    } catch (error) {
      if (mounted) setState(() => _actionError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _openingFile = false);
    }
  }

  Future<void> _copyExternalLink(Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    _showSnackBar('Enlace copiado al portapapeles.');
  }

  Future<void> _openExternalLink(Uri uri) async {
    try {
      await ref.read(moderationExternalLinkOpenerProvider)(uri);
      _showSnackBar('Enlace preparado: ${uri.host}');
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'No se pudo abrir el enlace externo.';
        });
      }
    }
  }

  void _goBackToQueue(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/moderation');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detail = widget.detail;
    final currentVersion = detail.currentVersion;
    final downloadState = ref.watch(moderationMaterialDownloadProvider);
    final latestDownload = downloadState.asData?.value;
    final hasSavedFileForMaterial =
        latestDownload != null &&
        latestDownload.materialId == detail.materialId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Material'),
        centerTitle: true,
        leading: IconButton(
          key: const Key('moderation_review_appbar_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a la cola',
          onPressed: () => _goBackToQueue(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    detail.subjectName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (detail.academicYear != null)
                  Chip(
                    label: Text('${detail.academicYear}'),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (detail.materialType.isNotEmpty)
                  Chip(
                    label: Text(detail.materialType.toUpperCase()),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    detail.status.trim().toUpperCase() == 'PENDING_REVIEW'
                        ? 'EN REVISIÓN'
                        : detail.status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              detail.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ID: ${detail.materialId}',
              key: Key('moderation_review_material_id_${detail.materialId}'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.outline,
              ),
            ),
            if (detail.reviewId != null) ...[
              const SizedBox(height: 2),
              Text(
                'Ticket de revisión: ${detail.reviewId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Subido por ${detail.authorName} · ${detail.careerName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (detail.professor != null && detail.professor!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Docente: ${detail.professor}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (detail.submittedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Enviado el ${_formatDate(detail.submittedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
            const Divider(height: 28),
            Text(
              'Descripción',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail.description.isNotEmpty
                  ? detail.description
                  : 'Sin descripción proporcionada.',
              style: theme.textTheme.bodyMedium,
            ),
            if (detail.tags.isNotEmpty) ...[
              const SizedBox(height: 18),
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
                children: detail.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Inspección del recurso',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (detail.isExternalLink || detail.externalLink != null)
              _buildExternalLinkSection(context, detail),
            if (!detail.isExternalLink)
              _buildFileInspectionSection(
                context,
                detail: detail,
                currentVersion: currentVersion,
                downloadState: downloadState,
                latestDownload: latestDownload,
                hasSavedFile: hasSavedFileForMaterial,
              ),
            if (_actionError != null) ...[
              const SizedBox(height: 10),
              Text(
                _actionError!,
                key: const Key('moderation_review_action_error'),
                style: TextStyle(color: colorScheme.error),
              ),
            ],
            if (!detail.isExternalLink &&
                detail.orderedVersions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildVersionHistorySection(
                context,
                versions: detail.orderedVersions,
                isDownloading: downloadState.isLoading,
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo inspección de moderación: verifica el contenido antes de emitir una resolución.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('moderation_review_back_button'),
              onPressed: () => _goBackToQueue(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver a la cola'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinkSection(
    BuildContext context,
    ModerationMaterialDetail detail,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final validUri = detail.validatedExternalUri;

    if (detail.hasUnsafeExternalLink) {
      return Card(
        margin: EdgeInsets.zero,
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.gpp_bad_outlined, color: colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El enlace externo usa un esquema no permitido y fue bloqueado por seguridad.',
                  key: const Key('moderation_unsafe_link_warning'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (validUri == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Este material de tipo enlace no incluye URL registrada.',
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    validUri.toString(),
                    key: const Key('moderation_external_link_url'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('moderation_open_link_button'),
                  onPressed: () => _openExternalLink(validUri),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir enlace externo'),
                ),
                OutlinedButton.icon(
                  key: const Key('moderation_copy_link_button'),
                  onPressed: () => _copyExternalLink(validUri),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar enlace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInspectionSection(
    BuildContext context, {
    required ModerationMaterialDetail detail,
    required MaterialVersion? currentVersion,
    required AsyncValue<ModerationDownloadResult?> downloadState,
    required ModerationDownloadResult? latestDownload,
    required bool hasSavedFile,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveSize = currentVersion?.fileSizeBytes ?? detail.fileSizeBytes;
    final effectiveMime =
        currentVersion?.mimeType ??
        (detail.mimeType?.isNotEmpty == true
            ? detail.mimeType!
            : detail.fileType);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentVersion?.originalFileName ??
                            'Archivo adjunto pendiente',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (effectiveMime.isNotEmpty) effectiveMime,
                          if (effectiveSize > 0) _formatBytes(effectiveSize),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                key: const Key('moderation_download_file_button'),
                onPressed: downloadState.isLoading || _openingFile
                    ? null
                    : () => _downloadFile(versionId: currentVersion?.id),
                icon:
                    downloadState.isLoading &&
                        _busyVersionId == currentVersion?.id
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  downloadState.isLoading &&
                          _busyVersionId == currentVersion?.id
                      ? 'Descargando para revisión...'
                      : 'Descargar archivo para revisión',
                ),
              ),
            ),
            if (latestDownload != null &&
                latestDownload.materialId == detail.materialId) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('moderation_open_file_button'),
                onPressed: _openingFile
                    ? null
                    : () => _openDownloadedFile(latestDownload),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  _openingFile ? 'Abriendo archivo...' : 'Abrir archivo',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVersionHistorySection(
    BuildContext context, {
    required List<MaterialVersion> versions,
    required bool isDownloading,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Versiones registradas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < versions.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${versions[i].versionNumber}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: i == 0
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              versions[i].originalFileName ??
                                  'Versión ${versions[i].versionNumber}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (versions[i].fileSizeBytes != null &&
                                versions[i].fileSizeBytes! > 0)
                              Text(
                                _formatBytes(versions[i].fileSizeBytes!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: Key(
                          'moderation_download_version_${versions[i].id}',
                        ),
                        tooltip:
                            'Descargar versión ${versions[i].versionNumber}',
                        onPressed: isDownloading || _openingFile
                            ? null
                            : () => _downloadFile(versionId: versions[i].id),
                        icon: const Icon(Icons.download_outlined),
                      ),
                    ],
                  ),
                ),
                if (i < versions.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
