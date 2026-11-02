import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de la subida real vía POST /materials (#285).
class MaterialUploadState {
  final bool isUploading;
  final MaterialDetail? created;
  final String? errorMessage;

  const MaterialUploadState({
    this.isUploading = false,
    this.created,
    this.errorMessage,
  });

  const MaterialUploadState.idle() : this();
  const MaterialUploadState.uploading() : this(isUploading: true);
  const MaterialUploadState.success(MaterialDetail detail)
    : this(created: detail);
  const MaterialUploadState.error(String message)
    : this(errorMessage: message);

  bool get isIdle => !isUploading && created == null && errorMessage == null;
  bool get isSuccess => created != null;
  bool get hasError => errorMessage != null;
}

/// Traduce el fallo de subida a un mensaje mostrable en español.
///
/// Los errores con respuesta usan el mensaje del backend cuando existe
/// (incluye el detalle de validaciones/Catalog); si no, un texto por código.
String materialUploadErrorMessage(Object error) {
  ApiException? api;
  if (error is DioException && error.error is ApiException) {
    api = error.error as ApiException;
  } else if (error is ApiException) {
    api = error;
  }
  if (api == null) {
    return 'No fue posible subir el material. Intenta nuevamente.';
  }
  final serverMessage = api.message.trim();
  switch (api.statusCode) {
    case 400:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'El servidor rechazó los datos. Revisa el formulario.';
    case 401:
      return 'No se pudo validar el autor de la subida. '
          'Vuelve a iniciar sesión e intenta nuevamente.';
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
          : 'No fue posible subir el material. Intenta nuevamente.';
  }
}

class MaterialUploadNotifier extends Notifier<MaterialUploadState> {
  @override
  MaterialUploadState build() => const MaterialUploadState.idle();

  /// Envía [request] al backend. Retorna true si el material quedó creado
  /// (201) y deja el detalle en [MaterialUploadState.created].
  Future<bool> upload(UploadMaterialRequest request) async {
    if (state.isUploading) return false;

    state = const MaterialUploadState.uploading();
    try {
      final repository = ref.read(dioMaterialRepositoryProvider);
      final created = await repository.upload(request);
      if (!ref.mounted) return false;
      state = MaterialUploadState.success(created);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = MaterialUploadState.error(materialUploadErrorMessage(e));
      return false;
    }
  }

  void reset() {
    state = const MaterialUploadState.idle();
  }
}

final materialUploadProvider =
    NotifierProvider<MaterialUploadNotifier, MaterialUploadState>(
      MaterialUploadNotifier.new,
    );
