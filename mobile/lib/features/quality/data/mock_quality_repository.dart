import 'package:dio/dio.dart';

import '../domain/models/quality_models.dart';
import '../domain/repositories/quality_repository.dart';

/// Implementación en memoria de [QualityRepository] para pruebas unitarias y de widgets.
///
/// Permite inyectar fixtures y simular respuestas del Gateway sin dependencias de red.
class MockQualityRepository implements QualityRepository {
  final List<Favorite> favorites;
  final Map<String, Rating> ratingsByMaterialId;
  final Map<String, RatingSummary> summariesByMaterialId;
  final List<Report> reports;
  final List<ModerationMaterial> moderationMaterials;
  final Map<String, ModerationOperation> operationsById;
  final Duration delay;
  Exception? errorToThrow;

  MockQualityRepository({
    List<Favorite>? initialFavorites,
    Map<String, Rating>? initialRatings,
    Map<String, RatingSummary>? initialSummaries,
    List<Report>? initialReports,
    List<ModerationMaterial>? initialModerationMaterials,
    Map<String, ModerationOperation>? initialOperations,
    this.delay = Duration.zero,
    this.errorToThrow,
  }) : favorites = initialFavorites ?? [],
       ratingsByMaterialId = initialRatings ?? {},
       summariesByMaterialId = initialSummaries ?? {},
       reports = initialReports ?? [],
       moderationMaterials = initialModerationMaterials ?? [],
       operationsById = initialOperations ?? {};

  Future<void> _simulate() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
  }

  @override
  Future<FavoritePage> getFavorites({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= favorites.length) {
      return FavoritePage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: favorites.length,
      );
    }
    final endIndex = (startIndex + pageSize < favorites.length)
        ? startIndex + pageSize
        : favorites.length;
    return FavoritePage(
      items: favorites.sublist(startIndex, endIndex),
      page: page,
      pageSize: pageSize,
      total: favorites.length,
    );
  }

  @override
  Future<Favorite> addFavorite(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final existingIndex = favorites.indexWhere((f) => f.materialId == materialId);
    if (existingIndex != -1) {
      return favorites[existingIndex];
    }
    final newFav = Favorite(
      id: 'mock-fav-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      createdAt: DateTime.now().toUtc(),
      available: true,
    );
    favorites.insert(0, newFav);
    return newFav;
  }

  @override
  Future<void> removeFavorite(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    favorites.removeWhere((f) => f.materialId == materialId);
  }

  @override
  Future<RatingSummary> getRatingSummary(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    return summariesByMaterialId[materialId] ??
        RatingSummary(materialId: materialId, count: 0, average: 0.0);
  }

  @override
  Future<Rating?> getMyRating(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    return ratingsByMaterialId[materialId];
  }

  @override
  Future<Rating> upsertRating(
    String materialId,
    RatingUpsert request, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final rating = Rating(
      id: 'mock-rating-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      userId: 'mock-current-user-uuid',
      score: request.score,
      comment: request.comment,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    ratingsByMaterialId[materialId] = rating;
    return rating;
  }

  @override
  Future<void> deleteMyRating(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    ratingsByMaterialId.remove(materialId);
  }

  @override
  Future<Report> createReport(
    String materialId,
    ReportCreate request, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final report = Report(
      id: 'mock-rep-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      userId: 'mock-current-user-uuid',
      reason: request.reason,
      details: request.details,
      status: ReportStatus.open,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    reports.insert(0, report);
    return report;
  }

  @override
  Future<ReportPage> getMyReports({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= reports.length) {
      return ReportPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: reports.length,
      );
    }
    final endIndex = (startIndex + pageSize < reports.length)
        ? startIndex + pageSize
        : reports.length;
    return ReportPage(
      items: reports.sublist(startIndex, endIndex),
      page: page,
      pageSize: pageSize,
      total: reports.length,
    );
  }

  @override
  Future<Report> getReportById(
    String reportId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final report = reports.firstWhere(
      (r) => r.id == reportId,
      orElse: () => throw QualityApiException(
        statusCode: 404,
        errorCode: 'REPORT_NOT_FOUND',
        message: 'Reporte no encontrado.',
      ),
    );
    return report;
  }

  @override
  Future<ModerationMaterialPage> listModerationMaterials({
    int page = 1,
    int pageSize = 20,
    QualityMaterialStatus? status,
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final filtered = status != null
        ? moderationMaterials.where((m) => m.status == status).toList()
        : moderationMaterials;
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= filtered.length) {
      return ModerationMaterialPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: filtered.length,
      );
    }
    final endIndex = (startIndex + pageSize < filtered.length)
        ? startIndex + pageSize
        : filtered.length;
    return ModerationMaterialPage(
      items: filtered.sublist(startIndex, endIndex),
      page: page,
      pageSize: pageSize,
      total: filtered.length,
    );
  }

  @override
  Future<ModerationMaterial> getModerationMaterial(
    String materialId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    return moderationMaterials.firstWhere(
      (m) => m.id == materialId,
      orElse: () => throw QualityApiException(
        statusCode: 404,
        errorCode: 'MATERIAL_NOT_FOUND',
        message: 'Material no encontrado para moderación.',
      ),
    );
  }

  @override
  Future<ModerationOperation> submitModerationDecision(
    String materialId,
    ModerationDecisionRequest request, {
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final op = ModerationOperation(
      id: 'mock-op-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      actorId: 'mock-moderator-uuid',
      action: request.action,
      reason: request.reason,
      expectedRevision: request.expectedRevision,
      state: ModerationOperationState.applied,
      result: AppliedMaterial(
        materialId: materialId,
        status: switch (request.action) {
          ModerationAction.approve => QualityMaterialStatus.published,
          ModerationAction.reject => QualityMaterialStatus.rejected,
          ModerationAction.retire => QualityMaterialStatus.retired,
          ModerationAction.reopen => QualityMaterialStatus.pendingReview,
          _ => QualityMaterialStatus.published,
        },
        verified: request.action == ModerationAction.verify,
        revision: request.expectedRevision + 1,
      ),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    operationsById[op.id] = op;
    return op;
  }

  @override
  Future<ModerationOperation> getModerationOperation(
    String operationId, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final op = operationsById[operationId];
    if (op == null) {
      throw QualityApiException(
        statusCode: 404,
        errorCode: 'OPERATION_NOT_FOUND',
        message: 'Operación de moderación no encontrada.',
      );
    }
    return op;
  }

  @override
  Future<ReportPage> listModerationReports({
    int page = 1,
    int pageSize = 20,
    ReportStatus? status,
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final filtered = status != null
        ? reports.where((r) => r.status == status).toList()
        : reports;
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= filtered.length) {
      return ReportPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: filtered.length,
      );
    }
    final endIndex = (startIndex + pageSize < filtered.length)
        ? startIndex + pageSize
        : filtered.length;
    return ReportPage(
      items: filtered.sublist(startIndex, endIndex),
      page: page,
      pageSize: pageSize,
      total: filtered.length,
    );
  }

  @override
  Future<Report> updateReportStatus(
    String reportId,
    ReportUpdate request, {
    CancelToken? cancelToken,
  }) async {
    await _simulate();
    final index = reports.indexWhere((r) => r.id == reportId);
    if (index == -1) {
      throw QualityApiException(
        statusCode: 404,
        errorCode: 'REPORT_NOT_FOUND',
        message: 'Reporte no encontrado para actualizar.',
      );
    }
    final current = reports[index];
    final updated = Report(
      id: current.id,
      materialId: current.materialId,
      userId: current.userId,
      reason: current.reason,
      details: current.details,
      status: request.status,
      resolutionNote: request.resolutionNote ?? current.resolutionNote,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    reports[index] = updated;
    return updated;
  }
}
