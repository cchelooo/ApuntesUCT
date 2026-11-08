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
/// exige autoría (403 si no es el autor). Solo una subida a la vez en toda
/// la app: si otro material tiene una en curso, esta hoja se bloquea hasta
/// que termine o se cancele (con botón para cancelarla).
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

  /// Último número de versión conocido al enviar: cubre el hueco mientras la
  /// subida está en vuelo (el estado `uploading` no conserva `created`).
  int? _submittedBase;

  /// Última versión conocida combinando todas las fuentes, porque cada una
  /// puede ir desactualizada: lo creado en esta hoja, lo enviado y aún en
  /// vuelo, lo conservado en el provider (p. ej. se cerró y reabrió la hoja
  /// antes de que terminara) y el prop del detalle.
  int _latestKnown(MaterialVersionUploadState upload) {
    var latest = widget.currentVersionNumber ?? 0;
    for (final v in [
      _createdVersionNumber,
      _submittedBase,
      upload.created?.versionNumber,
    ]) {
      if (v != null && v > latest) latest = v;
    }
    return latest;
  }

  @override
  void initState() {
    super.initState();
    // Limpia un error anterior al reabrir para la versión B. El éxito se
    // conserva: la confirmación no se muestra (bandera local), pero su
    // número sí cuenta para proponer la siguiente versión.
    // Si hay una subida en curso de ESTE material se conserva y se sigue
    // mostrando su progreso (el estado está aislado por materialId).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final upload = ref.read(materialVersionUploadProvider(widget.materialId));
      if (upload.hasError) {
        ref
            .read(materialVersionUploadProvider(widget.materialId).notifier)
            .reset();
      }
    });
  }

  Future<void> _pickFile() async {
    final upload = ref.read(materialVersionUploadProvider(widget.materialId));
    if (upload.hasError) {
      ref
          .read(materialVersionUploadProvider(widget.materialId).notifier)
          .reset();
    }
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
    // Solo una subida a la vez en toda la app: si otro material tiene una
    // en curso, esta hoja no inicia nada hasta que termine o se cancele.
    final lockedBy = ref.read(materialVersionUploadLockProvider);
    if (lockedBy != null && lockedBy != widget.materialId) return;
    final proposed =
        _latestKnown(
          ref.read(materialVersionUploadProvider(widget.materialId)),
        ) +
        1;
    setState(() {
      _attemptedHere = true;
      _submittedBase = proposed - 1;
    });
    final ok = await ref
        .read(materialVersionUploadProvider(widget.materialId).notifier)
        .uploadVersion(
          widget.materialId,
          LocalMaterialFile(
            fileName: picked.fileName,
            mimeType: picked.mimeType,
            bytes: picked.bytes,
          ),
        );
    // Solo una subida iniciada por ESTA hoja marca su confirmación: el
    // estado está aislado por materialId, así el éxito de otro material
    // nunca aparece aquí aunque complete mientras esta hoja está abierta.
    if (!mounted) return;
    setState(() {
      if (ok) {
        _createdVersionNumber = ref
            .read(materialVersionUploadProvider(widget.materialId))
            .created
            ?.versionNumber;
        _completedHere = true;
      }
      _submittedBase = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(materialVersionUploadProvider(widget.materialId));
    // Otro material con subida en curso bloquea esta hoja: no se puede
    // iniciar nada aquí hasta que termine o se cancele aquella.
    final lockedBy = ref.watch(materialVersionUploadLockProvider);
    final blockedByOther = lockedBy != null && lockedBy != widget.materialId;
    final nextVersion = _latestKnown(upload) + 1;
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
                  ref
                      .read(
                        materialVersionUploadProvider(widget.materialId)
                            .notifier,
                      )
                      .reset();
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
                'Se creará la versión v$nextVersion.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FormErrorBanner(
                message: _attemptedHere ? upload.errorMessage : null,
              ),
              if (blockedByOther) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.hourglass_top_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hay una subida en curso en otro material. '
                        'Espera a que termine o cancélala para subir aquí.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => ref
                      .read(materialVersionUploadProvider(lockedBy).notifier)
                      .cancel(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar subida en curso'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: (_isPicking || upload.isUploading || blockedByOther)
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
                // Icono + texto: el error no depende solo del color (#299).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fileError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
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
                  onPressed: () => ref
                      .read(
                        materialVersionUploadProvider(widget.materialId)
                            .notifier,
                      )
                      .cancel(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar subida'),
                ),
              ] else ...[
                AppPrimaryButton(
                  label: 'Confirmar subida de v$nextVersion',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: (_fileValid && !blockedByOther) ? _submit : null,
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
