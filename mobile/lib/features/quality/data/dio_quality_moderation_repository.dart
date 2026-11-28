import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../materials/domain/models/material_requests.dart';
import '../domain/models/moderation_material_detail.dart';
import '../domain/models/pending_moderation_item.dart';
import '../domain/repositories/quality_moderation_repository.dart';
import 'models/quality_moderation_detail_dto.dart';
import 'models/quality_moderation_queue_dto.dart';

/// Implementación HTTP de [QualityModerationRepository] vía API Gateway (#409, #410).
class DioQualityModerationRepository implements QualityModerationRepository {
  DioQualityModerationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  }) async {
    if (page < 1 ||
        pageSize < 1 ||
        pageSize > 100 ||
        page > 2147483647 ||
        (page - 1) * pageSize > 2147483647) {
      throw ArgumentError('Paginación fuera de los límites del contrato.');
    }

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/materials',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'La respuesta de Quality no es un objeto JSON.',
        );
      }
      return QualityModerationPageDto.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'Quality devolvió una respuesta de moderación inválida.',
        data: error,
      );
    }
  }

  @override
  Future<ModerationMaterialDetail> getPendingMaterialDetail(
    String materialId,
  ) async {
    final normalizedId = materialId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError(
        'El identificador del material no puede estar vacío.',
      );
    }

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/materials/${Uri.encodeComponent(normalizedId)}',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'El detalle de Quality no es un objeto JSON.',
        );
      }
      return QualityModerationDetailDto.fromJson(data).toDomain();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw ModerationMaterialNotFoundException(normalizedId);
      }
      throw _mapDioError(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'Quality devolvió un detalle de moderación inválido.',
        data: error,
      );
    }
  }

  @override
  Future<MaterialDownload> downloadPendingMaterial(
    String materialId, {
    String? versionId,
  }) async {
    final normalizedId = materialId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError(
        'El identificador del material no puede estar vacío.',
      );
    }

    final normalizedVersion = versionId?.trim();

    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/quality/moderation/materials/${Uri.encodeComponent(normalizedId)}/download',
        queryParameters:
            (normalizedVersion == null || normalizedVersion.isEmpty)
            ? null
            : {'versionId': normalizedVersion},
        options: Options(responseType: ResponseType.bytes),
      );
      return MaterialDownload(
        bytes: response.data ?? <int>[],
        fileName: _extractFilename(
          response.headers.value('content-disposition') ?? '',
        ),
        mimeType:
            response.headers.value('content-type') ??
            'application/octet-stream',
      );
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  ApiException _mapDioError(DioException error) {
    final response = error.response;
    if (response != null && response.data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(response.data as List<int>));
        return ApiException.fromDioException(
          error.copyWith(
            response: Response(
              requestOptions: error.requestOptions,
              statusCode: response.statusCode,
              data: decoded,
              headers: response.headers,
            ),
          ),
        );
      } on FormatException {
        // Conserva el estado HTTP original si el cuerpo binario no es JSON.
      }
    }
    final intercepted = error.error;
    if (intercepted is ApiException) return intercepted;
    return ApiException.fromDioException(error);
  }

  String _extractFilename(String disposition) {
    final extended = RegExp(
      r"filename\*=(?:UTF-8)''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (extended != null) {
      try {
        return Uri.decodeComponent(extended.group(1)!.trim());
      } on ArgumentError {
        // Si filename* está mal codificado, se intenta con filename estándar.
      }
    }
    return RegExp(
          r'filename="?([^";]+)"?',
          caseSensitive: false,
        ).firstMatch(disposition)?.group(1)?.trim() ??
        'material_pendiente';
  }
}
