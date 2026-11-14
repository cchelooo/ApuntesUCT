import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/quality/quality.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class QualityResponseAdapter implements HttpClientAdapter {
  QualityResponseAdapter(this.data, {this.statusCode = 200});
  Object? data;
  int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final bodyString = data != null ? jsonEncode(data) : '';
    return ResponseBody.fromString(
      bodyString,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;

  DioQualityRepository createRepo(QualityResponseAdapter adapter) {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://gateway.example.test/api/v1',
        headers: {
          'Authorization': 'Bearer mock.jwt.token',
        },
      ),
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioQualityRepository(ApiClient(customDio: dio));
  }

  const validMaterialUuid = '11111111-2222-4333-8444-555555555555';
  const validReportUuid = '99999999-8888-4777-8666-555555555555';
  const validOperationUuid = '33333333-3333-4333-8333-333333333333';

  group('Issue #395: DioQualityRepository - Consumo mediante Gateway', () {
    group('Favoritos (Favorites)', () {
      test('Criterio 1 & 2: getFavorites consulta /quality/favorites/me con paginación', () async {
        final adapter = QualityResponseAdapter({
          'items': [
            {
              'id': 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
              'materialId': validMaterialUuid,
              'createdAt': '2026-11-14T12:00:00Z',
              'available': true,
            }
          ],
          'page': 2,
          'pageSize': 15,
          'total': 16,
        });
        final repo = createRepo(adapter);

        final result = await repo.getFavorites(page: 2, pageSize: 15);

        expect(adapter.request?.path, '/quality/favorites/me');
        expect(adapter.request?.queryParameters, {'page': 2, 'pageSize': 15});
        expect(result.items.length, 1);
        expect(result.items.first.materialId, validMaterialUuid);
        expect(result.page, 2);
        expect(result.total, 16);
      });

      test('addFavorite realiza PUT /quality/materials/:id/favorite', () async {
        final adapter = QualityResponseAdapter({
          'id': 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
          'materialId': validMaterialUuid,
          'createdAt': '2026-11-14T12:00:00Z',
          'available': true,
        });
        final repo = createRepo(adapter);

        final result = await repo.addFavorite(validMaterialUuid);

        expect(adapter.request?.method, 'PUT');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/favorite');
        expect(result.materialId, validMaterialUuid);
      });

      test('removeFavorite realiza DELETE /quality/materials/:id/favorite', () async {
        final adapter = QualityResponseAdapter(null, statusCode: 204);
        final repo = createRepo(adapter);

        await repo.removeFavorite(validMaterialUuid);

        expect(adapter.request?.method, 'DELETE');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/favorite');
      });
    });

    group('Calificaciones (Ratings)', () {
      test('getRatingSummary realiza GET público /quality/materials/:id/ratings/summary', () async {
        final adapter = QualityResponseAdapter({
          'materialId': validMaterialUuid,
          'count': 12,
          'average': 4.5,
        });
        final repo = createRepo(adapter);

        final summary = await repo.getRatingSummary(validMaterialUuid);

        expect(adapter.request?.method, 'GET');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/ratings/summary');
        expect(summary.count, 12);
        expect(summary.average, 4.5);
      });

      test('getMyRating devuelve Rating cuando existe calificación propia', () async {
        final adapter = QualityResponseAdapter({
          'id': '77777777-6666-4555-8444-333333333333',
          'materialId': validMaterialUuid,
          'userId': '88888888-7777-4666-8555-444444444444',
          'score': 5,
          'comment': 'Excelente contenido.',
          'createdAt': '2026-11-13T10:00:00Z',
          'updatedAt': '2026-11-13T10:00:00Z',
        });
        final repo = createRepo(adapter);

        final rating = await repo.getMyRating(validMaterialUuid);

        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/ratings/me');
        expect(rating, isNotNull);
        expect(rating!.score, 5);
        expect(rating.comment, 'Excelente contenido.');
      });

      test('getMyRating retorna null ante 404 (usuario no ha calificado aún)', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 404,
          'code': 'RATING_NOT_FOUND',
          'message': 'No se encontró calificación del usuario para este material.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 404);
        final repo = createRepo(adapter);

        final rating = await repo.getMyRating(validMaterialUuid);

        expect(rating, isNull);
      });

      test('upsertRating realiza PUT /quality/materials/:id/ratings/me con score y comment', () async {
        final adapter = QualityResponseAdapter({
          'id': '77777777-6666-4555-8444-333333333333',
          'materialId': validMaterialUuid,
          'userId': '88888888-7777-4666-8555-444444444444',
          'score': 4,
          'comment': 'Buen material',
          'createdAt': '2026-11-14T10:00:00Z',
          'updatedAt': '2026-11-14T10:00:00Z',
        });
        final repo = createRepo(adapter);

        final result = await repo.upsertRating(
          validMaterialUuid,
          const RatingUpsert(score: 4, comment: 'Buen material'),
        );

        expect(adapter.request?.method, 'PUT');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/ratings/me');
        expect(adapter.request?.data, {'score': 4, 'comment': 'Buen material'});
        expect(result.score, 4);
      });

      test('deleteMyRating realiza DELETE /quality/materials/:id/ratings/me', () async {
        final adapter = QualityResponseAdapter(null, statusCode: 204);
        final repo = createRepo(adapter);

        await repo.deleteMyRating(validMaterialUuid);

        expect(adapter.request?.method, 'DELETE');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/ratings/me');
      });
    });

    group('Reportes (Reports)', () {
      test('createReport realiza POST /quality/materials/:id/reports', () async {
        final adapter = QualityResponseAdapter({
          'id': validReportUuid,
          'materialId': validMaterialUuid,
          'userId': '88888888-7777-4666-8555-444444444444',
          'reason': 'BROKEN_RESOURCE',
          'details': 'Enlace roto',
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-14T12:00:00Z',
          'updatedAt': '2026-11-14T12:00:00Z',
        }, statusCode: 201);
        final repo = createRepo(adapter);

        final result = await repo.createReport(
          validMaterialUuid,
          const ReportCreate(reason: ReportReason.brokenResource, details: 'Enlace roto'),
        );

        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.path, '/quality/materials/$validMaterialUuid/reports');
        expect(adapter.request?.data, {
          'reason': 'BROKEN_RESOURCE',
          'details': 'Enlace roto',
        });
        expect(result.id, validReportUuid);
      });

      test('getMyReports realiza GET /quality/reports/me con paginación', () async {
        final adapter = QualityResponseAdapter({
          'items': [],
          'page': 1,
          'pageSize': 20,
          'total': 0,
        });
        final repo = createRepo(adapter);

        final page = await repo.getMyReports();

        expect(adapter.request?.path, '/quality/reports/me');
        expect(page.items, isEmpty);
        expect(page.total, 0);
      });
    });

    group('Moderación (Moderation)', () {
      test('listModerationMaterials consulta /quality/moderation/materials con status', () async {
        final adapter = QualityResponseAdapter({
          'items': [],
          'page': 1,
          'pageSize': 10,
          'total': 0,
        });
        final repo = createRepo(adapter);

        await repo.listModerationMaterials(
          page: 1,
          pageSize: 10,
          status: QualityMaterialStatus.pendingReview,
        );

        expect(adapter.request?.path, '/quality/moderation/materials');
        expect(adapter.request?.queryParameters['status'], 'PENDING_REVIEW');
      });

      test('submitModerationDecision envía Idempotency-Key y DTO requerido', () async {
        final adapter = QualityResponseAdapter({
          'id': validOperationUuid,
          'materialId': validMaterialUuid,
          'actorId': '88888888-7777-4666-8555-444444444444',
          'action': 'APPROVE',
          'reason': 'Contenido correcto',
          'expectedRevision': 3,
          'state': 'APPLIED',
          'result': {
            'materialId': validMaterialUuid,
            'status': 'PUBLISHED',
            'verified': false,
            'revision': 4,
          },
          'failure': null,
          'createdAt': '2026-11-14T14:00:00Z',
          'updatedAt': '2026-11-14T14:00:01Z',
        }, statusCode: 202);
        final repo = createRepo(adapter);

        const request = ModerationDecisionRequest(
          action: ModerationAction.approve,
          expectedRevision: 3,
          reason: 'Contenido correcto',
        );

        final op = await repo.submitModerationDecision(
          validMaterialUuid,
          request,
          idempotencyKey: 'idemp-key-12345',
        );

        expect(adapter.request?.path, '/quality/moderation/materials/$validMaterialUuid/decisions');
        expect(adapter.request?.headers['Idempotency-Key'], 'idemp-key-12345');
        expect(op.id, validOperationUuid);
        expect(op.state, ModerationOperationState.applied);
      });
    });

    group('Criterio 3 & 4: Preservación de errores utilizables y sin éxito simulado', () {
      test('Error 400 de validación conserva statusCode, errorCode y field', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 400,
          'code': 'VALIDATION_ERROR',
          'message': 'El motivo de reporte es obligatorio.',
          'field': 'reason',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 400);
        final repo = createRepo(adapter);

        expect(
          () => repo.createReport(
            validMaterialUuid,
            const ReportCreate(reason: ReportReason.other),
          ),
          throwsA(
            isA<QualityApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.errorCode, 'errorCode', 'VALIDATION_ERROR')
                .having((e) => e.field, 'field', 'reason')
                .having((e) => e.message, 'message', 'El motivo de reporte es obligatorio.'),
          ),
        );
      });

      test('Error 401 Unauthorized se propaga sin simular éxito', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 401,
          'code': 'UNAUTHORIZED',
          'message': 'Token no válido o expirado.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 401);
        final repo = createRepo(adapter);

        expect(
          () => repo.getFavorites(),
          throwsA(
            isA<QualityApiException>()
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('Error 403 Forbidden para estudiante intentando moderación', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 403,
          'code': 'FORBIDDEN',
          'message': 'No tienes permisos de moderación.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 403);
        final repo = createRepo(adapter);

        expect(
          () => repo.listModerationMaterials(),
          throwsA(
            isA<QualityApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.errorCode, 'errorCode', 'FORBIDDEN'),
          ),
        );
      });

      test('Error 409 STALE_REVISION se propaga fielmente', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 409,
          'code': 'STALE_REVISION',
          'message': 'El material cambió. Vuelve a consultar antes de decidir.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 409);
        final repo = createRepo(adapter);

        expect(
          () => repo.submitModerationDecision(
            validMaterialUuid,
            const ModerationDecisionRequest(
              action: ModerationAction.approve,
              expectedRevision: 1,
            ),
          ),
          throwsA(
            isA<QualityApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.errorCode, 'errorCode', 'STALE_REVISION'),
          ),
        );
      });

      test('Error 502 Bad Gateway no se reemplaza por datos ficticios', () async {
        final adapter = QualityResponseAdapter({
          'statusCode': 502,
          'message': 'Quality Service no disponible en Gateway.',
        }, statusCode: 502);
        final repo = createRepo(adapter);

        expect(
          () => repo.getRatingSummary(validMaterialUuid),
          throwsA(
            isA<QualityApiException>()
                .having((e) => e.statusCode, 'statusCode', 502),
          ),
        );
      });
    });

    group('MockQualityRepository para pruebas locales y UI', () {
      test('Permite agregar, listar y eliminar favoritos en memoria', () async {
        final mockRepo = MockQualityRepository();

        final pageEmpty = await mockRepo.getFavorites();
        expect(pageEmpty.items, isEmpty);

        final added = await mockRepo.addFavorite(validMaterialUuid);
        expect(added.materialId, validMaterialUuid);

        final pageWithItem = await mockRepo.getFavorites();
        expect(pageWithItem.items.length, 1);

        await mockRepo.removeFavorite(validMaterialUuid);
        final pageAfterRemove = await mockRepo.getFavorites();
        expect(pageAfterRemove.items, isEmpty);
      });

      test('Permite calificar y consultar resumen en memoria', () async {
        final mockRepo = MockQualityRepository();

        expect(await mockRepo.getMyRating(validMaterialUuid), isNull);

        final rating = await mockRepo.upsertRating(
          validMaterialUuid,
          const RatingUpsert(score: 5, comment: 'Súper útil'),
        );
        expect(rating.score, 5);

        final read = await mockRepo.getMyRating(validMaterialUuid);
        expect(read?.score, 5);
        expect(read?.comment, 'Súper útil');

        await mockRepo.deleteMyRating(validMaterialUuid);
        expect(await mockRepo.getMyRating(validMaterialUuid), isNull);
      });
    });
  });
}
