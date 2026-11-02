import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Historial de versiones de un material (#293).
///
/// Muestra la versión actual identificada y las anteriores con número y
/// fecha. Cada fila de archivo permite descargar esa versión concreta (el
/// backend lo soporta vía `versionId`); los enlaces externos no tienen
/// versiones y el vacío se representa explícitamente, sin acciones falsas.
class MaterialVersionHistory extends ConsumerStatefulWidget {
  const MaterialVersionHistory({
    required this.materialId,
    required this.detail,
    super.key,
  });

  final String materialId;
  final MaterialDetail detail;

  @override
  ConsumerState<MaterialVersionHistory> createState() =>
      _MaterialVersionHistoryState();
}

class _MaterialVersionHistoryState
    extends ConsumerState<MaterialVersionHistory> {
  String? _busyVersionId;
  String? _error;

  bool get _isLink =>
      widget.detail.summary.materialType.trim().toUpperCase() == 'LINK';

  List<MaterialVersion> get _ordered {
    final versions = [...widget.detail.versions];
    versions.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return versions;
  }

  Future<void> _download(MaterialVersion version) async {
    if (_busyVersionId != null) return;
    setState(() {
      _busyVersionId = version.id;
      _error = null;
    });
    try {
      final result = await ref
          .read(materialDownloadProvider.notifier)
          .download(widget.materialId, versionId: version.id);
      if (!mounted || result == null) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Descarga completada: ${result.download.fileName}'),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () =>
                  _open(result.savedPath, result.download.mimeType),
            ),
          ),
        );
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busyVersionId = null);
    }
  }

  Future<void> _open(String path, String mimeType) async {
    try {
      await ref.read(materialFileHandlerProvider).open(path, mimeType);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  String _errorMessage(Object error) {
    if (error is MaterialFileException) return error.message;
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        404 => 'Esa versión ya no está disponible.',
        502 || 503 => 'El servicio no está disponible. Intenta nuevamente.',
        _ => error.message,
      };
    }
    return 'No se pudo descargar la versión. Intenta nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Historial de versiones',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLink) ...[
          _NoteCard(
            icon: Icons.link_outlined,
            message: 'Este material es un enlace externo: no tiene versiones de archivo.',
          ),
        ] else if (widget.detail.versions.isEmpty) ...[
          const _NoteCard(
            icon: Icons.history_outlined,
            message: 'Aún no hay versiones registradas para este material.',
          ),
        ] else ...[
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _ordered.length; i++) ...[
                  _VersionRow(
                    version: _ordered[i],
                    isCurrent: i == 0,
                    isBusy: _busyVersionId == _ordered[i].id,
                    busyAny: _busyVersionId != null,
                    onDownload: () => _download(_ordered[i]),
                  ),
                  if (i < _ordered.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: colorScheme.error)),
        ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.isCurrent,
    required this.isBusy,
    required this.busyAny,
    required this.onDownload,
  });

  final MaterialVersion version;
  final bool isCurrent;
  final bool isBusy;
  final bool busyAny;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = [
      if (version.createdAt != null) versionDateLabel(version.createdAt!),
      if (version.originalFileName != null) version.originalFileName!,
      if (version.fileSizeBytes != null && version.fileSizeBytes! > 0)
        versionSizeLabel(version.fileSizeBytes!),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'v${version.versionNumber}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCurrent
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
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isCurrent ? 'Versión actual' : 'Versión anterior',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Actual',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
              ],
            ),
          ),
          if (isBusy)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              tooltip: 'Descargar versión ${version.versionNumber}',
              onPressed: busyAny ? null : onDownload,
              icon: const Icon(Icons.download_outlined),
            ),
        ],
      ),
    );
  }
}

/// Fecha corta dd/mm/aaaa para las filas del historial.
String versionDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Tamaño legible para las filas del historial.
String versionSizeLabel(int bytes) {
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
