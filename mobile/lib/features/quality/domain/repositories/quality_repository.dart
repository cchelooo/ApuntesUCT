import 'package:dio/dio.dart';

import '../models/quality_models.dart';

/// Interfaz del repositorio de Quality para Mobile (Issue #395).
///
/// Centraliza todas las operaciones de calidad, favoritos, calificaciones,
/// reportes y moderación consumidas a través del API Gateway público.
abstract interface class QualityRepository {
  // ---------------------------------------------------------------------------
  // Favoritos (Favorites)
  // ---------------------------------------------------------------------------

  /// Obtiene la lista paginada de favoritos propios del usuario autenticado.
  Future<FavoritePage> getFavorites({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  });

  /// Guarda un material en la lista personal de favoritos del usuario activo.
  Future<Favorite> addFavorite(
    String materialId, {
    CancelToken? cancelToken,
  });

  /// Elimina un material de los favoritos del usuario activo.
  Future<void> removeFavorite(
    String materialId, {
    CancelToken? cancelToken,
  });

  // ---------------------------------------------------------------------------
  // Calificaciones (Ratings)
  // ---------------------------------------------------------------------------

  /// Obtiene el resumen público consolidado de calificaciones de un material.
  Future<RatingSummary> getRatingSummary(
    String materialId, {
    CancelToken? cancelToken,
  });

  /// Consulta la calificación emitida por el usuario autenticado para un material.
  /// Retorna `null` si el usuario no ha calificado dicho material (HTTP 404).
  Future<Rating?> getMyRating(
    String materialId, {
    CancelToken? cancelToken,
  });

  /// Crea o actualiza la calificación del usuario autenticado (1 a 5 estrellas).
  Future<Rating> upsertRating(
    String materialId,
    RatingUpsert request, {
    CancelToken? cancelToken,
  });

  /// Elimina la calificación emitida por el usuario activo para un material.
  Future<void> deleteMyRating(
    String materialId, {
    CancelToken? cancelToken,
  });

  // ---------------------------------------------------------------------------
  // Reportes (Reports)
  // ---------------------------------------------------------------------------

  /// Registra un nuevo reporte sobre un material publicado.
  Future<Report> createReport(
    String materialId,
    ReportCreate request, {
    CancelToken? cancelToken,
  });

  /// Lista los reportes presentados por el usuario autenticado.
  Future<ReportPage> getMyReports({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  });

  /// Consulta el detalle de un reporte específico por su ID.
  Future<Report> getReportById(
    String reportId, {
    CancelToken? cancelToken,
  });

  // ---------------------------------------------------------------------------
  // Moderación (Moderation)
  // ---------------------------------------------------------------------------

  /// Lista los materiales para moderación (requiere rol MODERATOR o ADMIN).
  Future<ModerationMaterialPage> listModerationMaterials({
    int page = 1,
    int pageSize = 20,
    QualityMaterialStatus? status,
    CancelToken? cancelToken,
  });

  /// Consulta el snapshot privado de un material para revisión.
  Future<ModerationMaterial> getModerationMaterial(
    String materialId, {
    CancelToken? cancelToken,
  });

  /// Registra una decisión de moderación idempotente sobre un material.
  Future<ModerationOperation> submitModerationDecision(
    String materialId,
    ModerationDecisionRequest request, {
    String? idempotencyKey,
    CancelToken? cancelToken,
  });

  /// Consulta el estado de aplicación de una operación de moderación por ID.
  Future<ModerationOperation> getModerationOperation(
    String operationId, {
    CancelToken? cancelToken,
  });

  /// Lista reportes para moderación y gestión administrativa.
  Future<ReportPage> listModerationReports({
    int page = 1,
    int pageSize = 20,
    ReportStatus? status,
    CancelToken? cancelToken,
  });

  /// Cambia el estado de tratamiento de un reporte (IN_REVIEW, RESOLVED, DISMISSED).
  Future<Report> updateReportStatus(
    String reportId,
    ReportUpdate request, {
    CancelToken? cancelToken,
  });
}
