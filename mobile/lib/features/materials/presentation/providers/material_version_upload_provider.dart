import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_detail_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bloqueo global de subidas de versión (#292): solo una subida a la vez
/// en toda la app. Si hay una subida en curso para álgebra, la hoja de
/// integración no permite iniciar otra hasta que termine o se cancele.
/// Contiene el [materialId] dueño de la subida en curso, o null si libre.
class MaterialVersionUploadLock extends Notifier<String?> {
  @override
  String? build() => null;

  /// Reserva la subida para [materialId]. Retorna false si otro material
  /// ya tiene una subida en curso.
  bool tryClaim(String materialId) {
    if (state != null && state != materialId) return false;
    state = materialId;
    return true;
  }

  void release(String materialId) {
    if (state == materialId) state = null;
  }
}

final materialVersionUploadLockProvider =
    NotifierProvider<MaterialVersionUploadLock, String?>(
      MaterialVersionUploadLock.new,
    );

/// Estado de la subida de una nueva versión (#292).
class MaterialVersionUploadState {
  final bool isUploading;
  final double? progress;
  final MaterialVersion? created;
  final String? errorMessage;

  const MaterialVersionUploadState({
    this.isUploading = false,
    this.progress,
    this.created,
    this.errorMessage,
  });

  const MaterialVersionUploadState.idle() : this();
  const MaterialVersionUploadState.uploading([double? progress])
    : this(isUploading: true, progress: progress);
  const MaterialVersionUploadState.success(MaterialVersion version)
    : this(created: version);
  const MaterialVersionUploadState.error(String message)
    : this(errorMessage: message);

  bool get isIdle => !isUploading && created == null && errorMessage == null;
  bool get isSuccess => created != null;
  bool get hasError => errorMessage != null;
}

/// Traduce el fallo de subida de versión a un mensaje mostrable en español.
String materialVersionUploadErrorMessage(Object error) {
  if (error is DioException && error.type == DioExceptionType.cancel) {
    return 'Subida cancelada.';
  }
  ApiException? api;
  if (error is DioException && error.error is ApiException) {
    api = error.error as ApiException;
  } else if (error is ApiException) {
    api = error;
  }
  if (api == null) {
    return 'No fue posible subir la versión. Intenta nuevamente.';
  }
  final serverMessage = api.message.trim();
  switch (api.statusCode) {
    case 400:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'El servidor rechazó el archivo. Revisa que no esté vacío.';
    case 401:
      return 'No se pudo validar el autor de la subida. '
          'Vuelve a iniciar sesión e intenta nuevamente.';
    case 403:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Solo el autor del material puede subir una nueva versión.';
    case 404:
      return 'El material ya no existe.';
    case 413:
      return 'El archivo supera el límite de 15 MB permitido.';
    case 415:
      return 'Formato de archivo no permitido. Usa PDF, Word o PowerPoint.';
    case 502:
      return 'El servicio de materiales no está disponible ahora. '
          'Intenta más tarde.';
    default:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'No fue posible subir la versión. Intenta nuevamente.';
  }
}

class MaterialVersionUploadNotifier
    extends Notifier<MaterialVersionUploadState> {
  CancelToken? _cancelToken;

  @override
  MaterialVersionUploadState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const MaterialVersionUploadState.idle();
  }

  /// Envía [file] como nueva versión de [materialId]. Retorna true si quedó
  /// creada (201) y refresca el detalle para mostrar el historial al día.
  /// Los llamados concurrentes se ignoran (sin duplicar versiones) y solo
  /// se permite una subida a la vez en toda la app (bloqueo global).
  Future<bool> uploadVersion(String materialId, LocalMaterialFile file) async {
    if (state.isUploading) return false;
    if (!ref
        .read(materialVersionUploadLockProvider.notifier)
        .tryClaim(materialId)) {
      return false;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const MaterialVersionUploadState.uploading();
    try {
      final repository = ref.read(dioMaterialRepositoryProvider);
      final created = await repository.createVersion(
        materialId,
        file,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (!ref.mounted) return;
          state = MaterialVersionUploadState.uploading(
            total > 0 ? sent / total : null,
          );
        },
      );
      if (!ref.mounted) return false;
      state = MaterialVersionUploadState.success(created);
      ref.invalidate(materialDetailProvider(materialId));
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = MaterialVersionUploadState.error(
        materialVersionUploadErrorMessage(e),
      );
      return false;
    } finally {
      _cancelToken = null;
      if (ref.mounted) {
        ref
            .read(materialVersionUploadLockProvider.notifier)
            .release(materialId);
      }
    }
  }

  void cancel() {
    _cancelToken?.cancel();
  }

  void reset() {
    _cancelToken = null;
    state = const MaterialVersionUploadState.idle();
  }
}

/// Estado de subida aislado por material: cada material tiene su propia
/// instancia (family por [materialId]), así la subida de A nunca contamina
/// la hoja de B (progreso, éxito o error ajenos). Además rige el bloqueo
/// global [materialVersionUploadLockProvider]: una sola subida a la vez.
final materialVersionUploadProvider =
    NotifierProvider.family<
      MaterialVersionUploadNotifier,
      MaterialVersionUploadState,
      String
    >((_) => MaterialVersionUploadNotifier());
