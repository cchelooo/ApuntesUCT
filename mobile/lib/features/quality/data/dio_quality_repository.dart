import 'dart:convert';
import 'dart:math';

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
/// - Incluye claves de idempotencia obligatorias (`Idempotency-Key`) en creación y
///   actualización de reportes y decisiones de moderación, conservándolas durante reintentos.
/// - Preserva errores de autenticación (401), autorización (403), validación (400),
///   conflictos (409) y microservicios no disponibles (502/503).
/// - No sustituye errores por simulaciones o éxitos falsos.
class DioQualityRepository implements QualityRepository {
  final ApiClient _apiClient;
  final String Function() _generateIdempotencyKey;
  final Map<String, String> _pendingIdempotencyKeys = {};

  DioQualityRepository(
    this._apiClient, {
    String Function()? idempotencyKeyGenerator,
  }) : _generateIdempotencyKey = idempotencyKeyGenerator ?? _defaultUuidV4;

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
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    _validateUuid(materialId, 'materialId');
    final payload = request.toJson();
    final fingerprint = 'createReport:$materialId:${jsonEncode(payload)}';
    final resolvedKey = _resolveIdempotencyKey(fingerprint, idempotencyKey);
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/quality/materials/$materialId/reports',
        data: payload,
        options: Options(headers: {'Idempotency-Key': resolvedKey}),
        cancelToken: cancelToken,
      );
      final report = Report.fromJson(QualityJson.object(response.data));
      _pendingIdempotencyKeys.remove(fingerprint);
      return report;
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
    final payload = request.toJson();
    final fingerprint =
        'submitModerationDecision:$materialId:${jsonEncode(payload)}';
    final resolvedKey = _resolveIdempotencyKey(fingerprint, idempotencyKey);
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/quality/moderation/materials/$materialId/decisions',
        data: payload,
        options: Options(headers: {'Idempotency-Key': resolvedKey}),
        cancelToken: cancelToken,
      );
      final operation = ModerationOperation.fromJson(
        QualityJson.object(response.data),
      );
      _pendingIdempotencyKeys.remove(fingerprint);
      return operation;
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
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    _validateUuid(reportId, 'reportId');
    final payload = request.toJson();
    final fingerprint = 'updateReportStatus:$reportId:${jsonEncode(payload)}';
    final resolvedKey = _resolveIdempotencyKey(fingerprint, idempotencyKey);
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/quality/moderation/reports/$reportId',
        data: payload,
        options: Options(headers: {'Idempotency-Key': resolvedKey}),
        cancelToken: cancelToken,
      );
      final report = Report.fromJson(QualityJson.object(response.data));
      _pendingIdempotencyKeys.remove(fingerprint);
      return report;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Validaciones, Idempotencia y Manejo de Errores
  // ---------------------------------------------------------------------------

  String _resolveIdempotencyKey(
    String operationFingerprint,
    String? explicitKey,
  ) {
    if (explicitKey != null) {
      final trimmed = explicitKey.trim();
      _validateUuid(trimmed, 'idempotencyKey');
      _pendingIdempotencyKeys[operationFingerprint] = trimmed;
      return trimmed;
    }
    final existing = _pendingIdempotencyKeys[operationFingerprint];
    if (existing != null) {
      return existing;
    }
    final generated = _generateIdempotencyKey().trim();
    _validateUuid(generated, 'idempotencyKey');
    _pendingIdempotencyKeys[operationFingerprint] = generated;
    return generated;
  }

  static String _defaultUuidV4() {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  void _validatePagination(int page, int pageSize) {
    if (page < 1 ||
        pageSize < 1 ||
        pageSize > 100 ||
        page > 2147483647 ||
        (page - 1) * pageSize > 2147483647) {
      throw ArgumentError(
        'Parámetros de paginación fuera de los límites del contrato.',
      );
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
