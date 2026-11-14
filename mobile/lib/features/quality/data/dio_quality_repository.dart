import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/quality_models.dart';
import '../domain/repositories/quality_repository.dart';

/// Implementación del repositorio de Quality consumiendo el API Gateway público (Issue #395).
///
/// Cumple con los criterios de aceptación:
/// - Rutas unificadas a través del Gateway (`/quality/...`).
/// - Sesión compartida administrada por `ApiClient`.
/// - Preserva errores de autenticación (401), autorización (403), validación (400),
///   conflictos (409) y microservicios no disponibles (502/503).
/// - No sustituye errores por simulaciones o éxitos falsos.
class DioQualityRepository implements QualityRepository {
  final ApiClient _apiClient;

  DioQualityRepository(this._apiClient);

  // ---------------------------------------------------------------------------
  // Favoritos
  // ---------------------------------------------------------------------------

  @override
  Future<FavoritePage> getFavorites({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    _validatePagination(page, pageSize);
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/favorites/me',
        queryParameters: {'page': page, 'pageSize': pageSize},
        cancelToken: cancelToken,
      );
      return FavoritePage.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Favorite> addFavorite(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/quality/materials/$materialId/favorite',
        cancelToken: cancelToken,
      );
      return Favorite.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> removeFavorite(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      await _apiClient.dio.delete<dynamic>(
        '/quality/materials/$materialId/favorite',
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Calificaciones
  // ---------------------------------------------------------------------------

  @override
  Future<RatingSummary> getRatingSummary(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/materials/$materialId/ratings/summary',
        cancelToken: cancelToken,
      );
      return RatingSummary.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Rating?> getMyRating(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/materials/$materialId/ratings/me',
        cancelToken: cancelToken,
      );
      return Rating.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      // 404 Not Found indica legítimamente que el usuario aún no califica este material
      if (e.response?.statusCode == 404 ||
          (e.error is ApiException &&
              (e.error as ApiException).statusCode == 404)) {
        return null;
      }
      _handleError(e);
    }
  }

  @override
  Future<Rating> upsertRating(
    String materialId,
    RatingUpsert request, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/quality/materials/$materialId/ratings/me',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      return Rating.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> deleteMyRating(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      await _apiClient.dio.delete<dynamic>(
        '/quality/materials/$materialId/ratings/me',
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Reportes
  // ---------------------------------------------------------------------------

  @override
  Future<Report> createReport(
    String materialId,
    ReportCreate request, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/quality/materials/$materialId/reports',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      return Report.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<ReportPage> getMyReports({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    _validatePagination(page, pageSize);
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/reports/me',
        queryParameters: {'page': page, 'pageSize': pageSize},
        cancelToken: cancelToken,
      );
      return ReportPage.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Report> getReportById(
    String reportId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(reportId, 'reportId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/reports/$reportId',
        cancelToken: cancelToken,
      );
      return Report.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Moderación
  // ---------------------------------------------------------------------------

  @override
  Future<ModerationMaterialPage> listModerationMaterials({
    int page = 1,
    int pageSize = 20,
    QualityMaterialStatus? status,
    CancelToken? cancelToken,
  }) async {
    _validatePagination(page, pageSize);
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status.code,
      };
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/materials',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
      return ModerationMaterialPage.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<ModerationMaterial> getModerationMaterial(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/materials/$materialId',
        cancelToken: cancelToken,
      );
      return ModerationMaterial.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<ModerationOperation> submitModerationDecision(
    String materialId,
    ModerationDecisionRequest request, {
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    try {
      final options = Options(
        headers: {
          if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
            'Idempotency-Key': idempotencyKey.trim(),
        },
      );
      final response = await _apiClient.dio.post<dynamic>(
        '/quality/moderation/materials/$materialId/decisions',
        data: request.toJson(),
        options: options,
        cancelToken: cancelToken,
      );
      return ModerationOperation.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<ModerationOperation> getModerationOperation(
    String operationId, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(operationId, 'operationId');
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/operations/$operationId',
        cancelToken: cancelToken,
      );
      return ModerationOperation.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<ReportPage> listModerationReports({
    int page = 1,
    int pageSize = 20,
    ReportStatus? status,
    CancelToken? cancelToken,
  }) async {
    _validatePagination(page, pageSize);
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status.code,
      };
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/reports',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
      return ReportPage.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<Report> updateReportStatus(
    String reportId,
    ReportUpdate request, {
    CancelToken? cancelToken,
  }) async {
    _validateUuid(reportId, 'reportId');
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/quality/moderation/reports/$reportId',
        data: request.toJson(),
        cancelToken: cancelToken,
      );
      return Report.fromJson(QualityJson.object(response.data));
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Validaciones y Manejo de Errores
  // ---------------------------------------------------------------------------

  void _validatePagination(int page, int pageSize) {
    if (page < 1 ||
        pageSize < 1 ||
        pageSize > 100 ||
        page > 2147483647 ||
        (page - 1) * pageSize > 2147483647) {
      throw ArgumentError('Parámetros de paginación fuera de los límites del contrato.');
    }
  }

  void _validateUuid(String value, String name) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!regex.hasMatch(value.trim())) {
      throw ArgumentError('$name debe ser un UUID válido.');
    }
  }

  Never _handleError(DioException error) {
    final intercepted = error.error;
    if (intercepted is ApiException) {
      throw QualityApiException.fromApiException(intercepted);
    }
    throw QualityApiException.fromApiException(
      ApiException.fromDioException(error),
    );
  }
}
