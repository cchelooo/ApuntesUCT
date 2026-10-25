import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/core/widgets/form_error_banner.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_version_upload_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/utils/material_file_picker.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hoja para subir una nueva versión de archivo de un material (#292).
///
/// Flujo: elegir archivo → confirmar (la versión anterior no se elimina) →
/// progreso → éxito/error. El botón de envío se deshabilita mientras sube
/// para no duplicar versiones. El repositorio valida tipo LINK y el backend
/// exige autoría (403 si no es el autor).
class MaterialVersionUploadSheet extends ConsumerStatefulWidget {
  const MaterialVersionUploadSheet({
    required this.materialId,
    required this.currentVersionNumber,
    this.pickFile,
    super.key,
  });

  final String materialId;

  /// Número de la versión actual (null si aún no hay): la nueva será +1.
  final int? currentVersionNumber;

  /// Seam para tests: reemplaza el selector nativo sin usar MethodChannels.
  final Future<MaterialPickedFile?> Function()? pickFile;

  @override
  ConsumerState<MaterialVersionUploadSheet> createState() =>
      _MaterialVersionUploadSheetState();
}

class _MaterialVersionUploadSheetState
    extends ConsumerState<MaterialVersionUploadSheet> {
  MaterialPickedFile? _picked;
  bool _isPicking = false;
  String? _fileError;

  /// Número de la última versión creada en esta hoja: al subir "otra", la
  /// propuesta avanza (v3 → v4) aunque el detalle aún no se haya refrescado.
  int? _createdVersionNumber;

  /// La confirmación solo se muestra por una subida de ESTA hoja: al reabrir
  /// para una versión B, el éxito de la versión A no aparece sin haber
  /// subido nada (aunque el provider aún lo conserve).
  bool _completedHere = false;

  /// El error solo se muestra tras un intento de ESTA hoja.
  bool _attemptedHere = false;

  int get _nextVersion =>
      (_createdVersionNumber ?? widget.currentVersionNumber ?? 0) + 1;

  @override
  void initState() {
    super.initState();
    // Limpia un resultado anterior (versión A) al reabrir para la versión B.
    // Si hay una subida en curso se conserva y se sigue mostrando su progreso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final upload = ref.read(materialVersionUploadProvider);
      if (!upload.isUploading) {
        ref.read(materialVersionUploadProvider.notifier).reset();
      }
    });
  }

  Future<void> _pickFile() async {
    ref.read(materialVersionUploadProvider.notifier).reset();
    setState(() {
      _isPicking = true;
      _fileError = null;
    });
    try {
      final picked = widget.pickFile != null
          ? await widget.pickFile!()
          : await pickMaterialFile();
      if (!mounted || picked == null) return;
      setState(() {
        _picked = picked;
        _fileError = MaterialUploadValidation.validatePickedFile(
          fileName: picked.fileName,
          sizeBytes: picked.sizeBytes,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileError = 'No fue posible leer el archivo. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  bool get _fileValid {
    final picked = _picked;
    if (picked == null || picked.bytes.isEmpty) return false;
    return MaterialUploadValidation.validatePickedFile(
          fileName: picked.fileName,
          sizeBytes: picked.sizeBytes,
        ) ==
        null;
  }

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null) {
      setState(() => _fileError = 'Selecciona un archivo.');
      return;
    }
    if (picked.bytes.isEmpty) {
      setState(
        () => _fileError = 'No fue posible leer el archivo. Intenta de nuevo.',
      );
      return;
    }
    final invalid = MaterialUploadValidation.validatePickedFile(
      fileName: picked.fileName,
      sizeBytes: picked.sizeBytes,
    );
    if (invalid != null) {
      setState(() => _fileError = invalid);
      return;
    }
    setState(() => _attemptedHere = true);
    await ref
        .read(materialVersionUploadProvider.notifier)
        .uploadVersion(
          widget.materialId,
          LocalMaterialFile(
            fileName: picked.fileName,
            mimeType: picked.mimeType,
            bytes: picked.bytes,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Un éxito que complete en segundo plano (hoja cerrada y reabierta
    // durante la subida) también cuenta como completado aquí.
    ref.listen<MaterialVersionUploadState>(materialVersionUploadProvider, (
      _,
      next,
    ) {
      if (!mounted || !next.isSuccess || next.created == null) return;
      setState(() {
        _createdVersionNumber = next.created!.versionNumber;
        _completedHere = true;
      });
    });
    final upload = ref.watch(materialVersionUploadProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (upload.created != null && upload.isSuccess && _completedHere)
              _SuccessBody(
                versionNumber: upload.created!.versionNumber,
                fileName: _picked?.fileName,
                onClose: () => Navigator.of(context).pop(),
                onAgain: () {
                  ref.read(materialVersionUploadProvider.notifier).reset();
                  setState(() {
                    _picked = null;
                    _fileError = null;
                    _completedHere = false;
                    _attemptedHere = false;
                  });
                },
              )
            else ...[
              Text(
                'Subir nueva versión',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'La versión anterior no se elimina: quedará disponible en el historial. '
                'Se creará la versión v$_nextVersion.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FormErrorBanner(
                message: _attemptedHere ? upload.errorMessage : null,
              ),
              OutlinedButton.icon(
                onPressed: (_isPicking || upload.isUploading)
                    ? null
                    : _pickFile,
                icon: _isPicking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open_outlined),
                label: Text(
                  _picked == null
                      ? 'Seleccionar archivo (PDF, Word, PPT · máx. 15 MB)'
                      : 'Cambiar archivo',
                ),
              ),
              if (_picked != null) ...[
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      _picked!.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      MaterialUploadValidation.formatBytes(_picked!.sizeBytes),
                    ),
                    trailing: upload.isUploading
                        ? null
                        : IconButton(
                            tooltip: 'Quitar archivo',
                            icon: const Icon(Icons.close_outlined),
                            onPressed: () => setState(() {
                              _picked = null;
                              _fileError = null;
                            }),
                          ),
                  ),
                ),
              ],
              if (_fileError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (upload.isUploading) ...[
                LinearProgressIndicator(value: upload.progress),
                const SizedBox(height: 8),
                Text(
                  upload.progress != null
                      ? 'Subiendo… ${(upload.progress! * 100).toStringAsFixed(0)} %'
                      : 'Subiendo…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(materialVersionUploadProvider.notifier).cancel(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar subida'),
                ),
              ] else ...[
                AppPrimaryButton(
                  label: 'Confirmar subida de v$_nextVersion',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: _fileValid ? _submit : null,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    required this.versionNumber,
    required this.fileName,
    required this.onClose,
    required this.onAgain,
  });

  final int versionNumber;
  final String? fileName;
  final VoidCallback onClose;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 56, color: colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Versión v$versionNumber creada',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          fileName == null
              ? 'La nueva versión ya está disponible en el historial.'
              : '“$fileName” ya está disponible como v$versionNumber. '
                    'La versión anterior sigue en el historial.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: 'Cerrar',
          icon: Icons.check_outlined,
          onPressed: onClose,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.add_outlined),
          label: const Text('Subir otra versión'),
        ),
      ],
    );
  }
}
