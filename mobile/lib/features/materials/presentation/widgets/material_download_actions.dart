import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/material_file_handler.dart';
import '../providers/material_download_provider.dart';

class MaterialDownloadActions extends ConsumerStatefulWidget {
  const MaterialDownloadActions({
    required this.materialId,
    this.versionId,
    super.key,
  });

  final String materialId;
  final String? versionId;

  @override
  ConsumerState<MaterialDownloadActions> createState() =>
      _MaterialDownloadActionsState();
}

class _MaterialDownloadActionsState
    extends ConsumerState<MaterialDownloadActions> {
  bool _opening = false;
  String? _openError;

  Future<void> _download() async {
    setState(() => _openError = null);
    try {
      final result = await ref
          .read(materialDownloadProvider.notifier)
          .download(widget.materialId, versionId: widget.versionId);
      if (!mounted || result == null) return;
      _message('Descarga completada: ${result.download.fileName}');
    } catch (error) {
      if (mounted) _message(_errorMessage(error));
    }
  }

  Future<void> _open(DownloadResult result) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openError = null;
    });
    try {
      await ref
          .read(materialFileHandlerProvider)
          .open(result.savedPath, result.download.mimeType);
    } catch (error) {
      if (mounted) setState(() => _openError = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is MaterialFileException) return error.message;
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Tu sesión no es válida. Vuelve a iniciar sesión.',
        404 => 'El archivo ya no está disponible.',
        502 || 503 => 'El servicio no está disponible. Intenta nuevamente.',
        _ => error.message,
      };
    }
    return 'No se pudo descargar el material. Intenta nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(materialDownloadProvider);
    final result = state.asData?.value;
    final saved =
        result != null &&
        result.materialId == widget.materialId &&
        result.versionId == widget.versionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: state.isLoading || _opening ? null : _download,
            icon: state.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              state.isLoading
                  ? 'Descargando material...'
                  : state.hasError
                  ? 'Reintentar descarga'
                  : 'Descargar Material',
            ),
          ),
        ),
        if (state.hasError) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage(state.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (saved) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _opening ? null : () => _open(result),
            icon: const Icon(Icons.open_in_new),
            label: Text(_opening ? 'Abriendo archivo...' : 'Abrir archivo'),
          ),
        ],
        if (_openError != null) ...[
          const SizedBox(height: 8),
          Text(
            _openError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
