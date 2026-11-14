import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/features/quality/domain/models/quality_models.dart';

void main() {
  group('Issue #394: Modelos Mobile para las respuestas de Quality', () {
    group('Favoritos (Favorite & FavoritePage)', () {
      test('Criterio 1 & 4: Parsea FavoriteDto fiel al contrato de OpenAPI', () {
        final json = {
          'id': 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
          'materialId': 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
          'createdAt': '2026-11-14T12:00:00Z',
          'available': true,
        };

        final favorite = Favorite.fromJson(json);

        expect(favorite.id, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d');
        expect(favorite.materialId, 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e');
        expect(favorite.available, isTrue);
        expect(favorite.createdAt, DateTime.utc(2026, 11, 14, 12, 0, 0));

        final serialized = favorite.toJson();
        expect(serialized['id'], favorite.id);
        expect(serialized['materialId'], favorite.materialId);
        expect(serialized['available'], isTrue);
        expect(serialized['createdAt'], '2026-11-14T12:00:00.000Z');
      });

      test('Criterio 2: Favorite no reemplaza campos y rechaza UUID inválido', () {
        final invalidUuidJson = {
          'id': 'invalid-uuid',
          'materialId': 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
          'createdAt': '2026-11-14T12:00:00Z',
          'available': false,
        };

        expect(
          () => Favorite.fromJson(invalidUuidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('Criterio 3: FavoritePage calcula metadatos y preserva items', () {
        final pageJson = {
          'items': [
            {
              'id': 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
              'materialId': 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
              'createdAt': '2026-11-14T10:00:00Z',
              'available': true,
            },
            {
              'id': 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f',
              'materialId': 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a',
              'createdAt': '2026-11-14T11:00:00Z',
              'available': false,
            },
          ],
          'page': 1,
          'pageSize': 10,
          'total': 25,
        };

        final page = FavoritePage.fromJson(pageJson);

        expect(page.items.length, 2);
        expect(page.page, 1);
        expect(page.pageSize, 10);
        expect(page.total, 25);
        expect(page.totalPages, 3);
        expect(page.hasNextPage, isTrue);
        expect(page.items[0].available, isTrue);
        expect(page.items[1].available, isFalse);
      });
    });

    group('Calificaciones (Rating, RatingSummary, RatingUpsert)', () {
      test('Criterio 1: RatingDto parsea con comentario opcional presente', () {
        final json = {
          'id': '11111111-2222-4333-8444-555555555555',
          'materialId': '22222222-3333-4444-8555-666666666666',
          'userId': '33333333-4444-4555-8666-777777777777',
          'score': 5,
          'comment': 'Explicación clara y ejercicios útiles.',
          'createdAt': '2026-11-13T15:00:00Z',
          'updatedAt': '2026-11-13T15:30:00Z',
        };

        final rating = Rating.fromJson(json);

        expect(rating.score, 5);
        expect(rating.comment, 'Explicación clara y ejercicios útiles.');
        expect(rating.materialId, '22222222-3333-4444-8555-666666666666');
        expect(rating.userId, '33333333-4444-4555-8666-777777777777');

        final serialized = rating.toJson();
        expect(serialized['comment'], 'Explicación clara y ejercicios útiles.');
      });

      test('Criterio 2: RatingDto maneja comentario opcional nulo sin sustitutos ficticios', () {
        final json = {
          'id': '11111111-2222-4333-8444-555555555555',
          'materialId': '22222222-3333-4444-8555-666666666666',
          'userId': '33333333-4444-4555-8666-777777777777',
          'score': 4,
          'comment': null,
          'createdAt': '2026-11-13T15:00:00Z',
          'updatedAt': '2026-11-13T15:00:00Z',
        };

        final rating = Rating.fromJson(json);

        expect(rating.score, 4);
        expect(rating.comment, isNull);
        expect(rating.toJson().containsKey('comment'), isFalse);
      });

      test('Rating valida que la puntuación esté en el rango 1 a 5', () {
        final jsonInvalidScore = {
          'id': '11111111-2222-4333-8444-555555555555',
          'materialId': '22222222-3333-4444-8555-666666666666',
          'userId': '33333333-4444-4555-8666-777777777777',
          'score': 6,
          'createdAt': '2026-11-13T15:00:00Z',
          'updatedAt': '2026-11-13T15:00:00Z',
        };

        expect(
          () => Rating.fromJson(jsonInvalidScore),
          throwsA(isA<FormatException>()),
        );
      });

      test('RatingSummaryDto parsea promedios y conteos exactos', () {
        final json = {
          'materialId': '22222222-3333-4444-8555-666666666666',
          'count': 18,
          'average': 4.75,
        };

        final summary = RatingSummary.fromJson(json);

        expect(summary.count, 18);
        expect(summary.average, 4.75);
        expect(summary.materialId, '22222222-3333-4444-8555-666666666666');
      });

      test('RatingUpsert serializa con o sin comentario', () {
        const upsert1 = RatingUpsert(score: 5, comment: 'Excelente');
        expect(upsert1.toJson(), {'score': 5, 'comment': 'Excelente'});

        const upsert2 = RatingUpsert(score: 3);
        expect(upsert2.toJson(), {'score': 3});
      });
    });

    group('Reportes (Report, ReportCreate, ReportUpdate, ReportPage)', () {
      test('Criterio 1: Enums ReportReason y ReportStatus cumplen contrato exacto', () {
        expect(ReportReason.inappropriateContent.code, 'INAPPROPRIATE_CONTENT');
        expect(ReportReason.copyright.code, 'COPYRIGHT');
        expect(ReportReason.incorrectInformation.code, 'INCORRECT_INFORMATION');
        expect(ReportReason.brokenResource.code, 'BROKEN_RESOURCE');
        expect(ReportReason.other.code, 'OTHER');

        expect(ReportReason.fromJson('BROKEN_RESOURCE'), ReportReason.brokenResource);
        expect(ReportReason.fromJson('copyright'), ReportReason.copyright);

        expect(ReportStatus.open.code, 'OPEN');
        expect(ReportStatus.inReview.code, 'IN_REVIEW');
        expect(ReportStatus.resolved.code, 'RESOLVED');
        expect(ReportStatus.dismissed.code, 'DISMISSED');

        expect(ReportStatus.fromJson('IN_REVIEW'), ReportStatus.inReview);
      });

      test('ReportDto parsea respuesta completa con campos opcionales', () {
        final json = {
          'id': '99999999-8888-4777-8666-555555555555',
          'materialId': '22222222-3333-4444-8555-666666666666',
          'userId': '33333333-4444-4555-8666-777777777777',
          'reason': 'BROKEN_RESOURCE',
          'details': 'El enlace externo ya no permite acceder al documento.',
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-13T10:00:00Z',
          'updatedAt': '2026-11-13T10:00:00Z',
        };

        final report = Report.fromJson(json);

        expect(report.id, '99999999-8888-4777-8666-555555555555');
        expect(report.reason, ReportReason.brokenResource);
        expect(report.status, ReportStatus.open);
        expect(report.details, 'El enlace externo ya no permite acceder al documento.');
        expect(report.resolutionNote, isNull);

        final serialized = report.toJson();
        expect(serialized['reason'], 'BROKEN_RESOURCE');
        expect(serialized['status'], 'OPEN');
        expect(serialized.containsKey('resolutionNote'), isFalse);
      });

      test('ReportCreate y ReportUpdate serializan según contratos', () {
        const create = ReportCreate(
          reason: ReportReason.copyright,
          details: 'Uso no autorizado.',
        );
        expect(create.toJson(), {
          'reason': 'COPYRIGHT',
          'details': 'Uso no autorizado.',
        });

        final update = ReportUpdate(
          status: ReportStatus.resolved,
          expectedUpdatedAt: DateTime.utc(2026, 11, 13, 12, 0, 0),
          resolutionNote: 'Material corregido.',
        );
        expect(update.toJson(), {
          'status': 'RESOLVED',
          'expectedUpdatedAt': '2026-11-13T12:00:00.000Z',
          'resolutionNote': 'Material corregido.',
        });
      });

      test('ReportPageDto deserializa lista paginada', () {
        final pageJson = {
          'items': [
            {
              'id': '99999999-8888-4777-8666-555555555555',
              'materialId': '22222222-3333-4444-8555-666666666666',
              'userId': '33333333-4444-4555-8666-777777777777',
              'reason': 'OTHER',
              'details': 'Observación general',
              'status': 'RESOLVED',
              'resolutionNote': 'Atendido por moderador',
              'createdAt': '2026-11-12T10:00:00Z',
              'updatedAt': '2026-11-13T12:00:00Z',
            }
          ],
          'page': 1,
          'pageSize': 20,
          'total': 1,
        };

        final page = ReportPage.fromJson(pageJson);
        expect(page.items.length, 1);
        expect(page.items.first.reason, ReportReason.other);
        expect(page.items.first.resolutionNote, 'Atendido por moderador');
      });
    });

    group('Moderación (ModerationOperation, ModerationMaterial, QualityMaterialStatus)', () {
      test('QualityMaterialStatus reconoce los 4 estados canónicos', () {
        expect(QualityMaterialStatus.pendingReview.code, 'PENDING_REVIEW');
        expect(QualityMaterialStatus.published.code, 'PUBLISHED');
        expect(QualityMaterialStatus.rejected.code, 'REJECTED');
        expect(QualityMaterialStatus.retired.code, 'RETIRED');

        expect(QualityMaterialStatus.fromJson('RETIRED'), QualityMaterialStatus.retired);
        expect(QualityMaterialStatus.fromJson('WITHDRAWN'), QualityMaterialStatus.retired);
        expect(QualityMaterialStatus.fromJson('PENDIENTE'), QualityMaterialStatus.pendingReview);
      });

      test('ModerationAction reconoce las 6 acciones contractuales', () {
        expect(ModerationAction.approve.code, 'APPROVE');
        expect(ModerationAction.reject.code, 'REJECT');
        expect(ModerationAction.verify.code, 'VERIFY');
        expect(ModerationAction.revokeVerification.code, 'REVOKE_VERIFICATION');
        expect(ModerationAction.retire.code, 'RETIRE');
        expect(ModerationAction.reopen.code, 'REOPEN');

        expect(ModerationAction.fromJson('APPROVE'), ModerationAction.approve);
      });

      test('ModerationOperationDto parsea el ejemplo representativo del contrato OpenAPI', () {
        final exampleJson = {
          'id': '33333333-3333-4333-8333-333333333333',
          'materialId': '22222222-2222-4222-8222-222222222222',
          'actorId': '11111111-1111-4111-8111-111111111111',
          'action': 'APPROVE',
          'reason': null,
          'expectedRevision': 4,
          'state': 'PENDING_APPLICATION',
          'result': null,
          'failure': null,
          'createdAt': '2026-11-13T15:00:00Z',
          'updatedAt': '2026-11-13T15:00:00Z',
        };

        final op = ModerationOperation.fromJson(exampleJson);

        expect(op.id, '33333333-3333-4333-8333-333333333333');
        expect(op.action, ModerationAction.approve);
        expect(op.state, ModerationOperationState.pendingApplication);
        expect(op.reason, isNull);
        expect(op.result, isNull);
        expect(op.failure, isNull);
      });

      test('ModerationOperationDto parsea con resultado AppliedMaterial y OperationFailure', () {
        final appliedJson = {
          'id': '33333333-3333-4333-8333-333333333333',
          'materialId': '22222222-2222-4222-8222-222222222222',
          'actorId': '11111111-1111-4111-8111-111111111111',
          'action': 'VERIFY',
          'reason': 'Contenido verificado por docente',
          'expectedRevision': 5,
          'state': 'APPLIED',
          'result': {
            'materialId': '22222222-2222-4222-8222-222222222222',
            'status': 'PUBLISHED',
            'verified': true,
            'revision': 6,
          },
          'failure': null,
          'createdAt': '2026-11-13T16:00:00Z',
          'updatedAt': '2026-11-13T16:00:01Z',
        };

        final op = ModerationOperation.fromJson(appliedJson);

        expect(op.state, ModerationOperationState.applied);
        expect(op.result, isNotNull);
        expect(op.result!.verified, isTrue);
        expect(op.result!.status, QualityMaterialStatus.published);
        expect(op.result!.revision, 6);
      });

      test('ModerationMaterialDto parsea snapshot de material con versiones', () {
        final materialJson = {
          'id': '22222222-2222-4222-8222-222222222222',
          'uploaderId': '11111111-1111-4111-8111-111111111111',
          'title': 'Guía Completa de Álgebra Lineal',
          'description': 'Ejercicios resueltos y teoremas demostrados.',
          'materialType': 'DOCUMENT',
          'externalLink': null,
          'status': 'PENDING_REVIEW',
          'verified': false,
          'revision': 2,
          'currentVersionId': '44444444-4444-4444-8444-444444444444',
          'versions': [
            {
              'id': '44444444-4444-4444-8444-444444444444',
              'versionNumber': 1,
              'originalFilename': 'algebra_v1.pdf',
              'mimeType': 'application/pdf',
              'fileSize': '2048000',
              'createdAt': '2026-11-12T14:00:00Z',
            }
          ],
          'createdAt': '2026-11-12T14:00:00Z',
          'updatedAt': '2026-11-12T14:00:00Z',
        };

        final material = ModerationMaterial.fromJson(materialJson);

        expect(material.id, '22222222-2222-4222-8222-222222222222');
        expect(material.status, QualityMaterialStatus.pendingReview);
        expect(material.verified, isFalse);
        expect(material.revision, 2);
        expect(material.versions.length, 1);
        expect(material.versions.first.originalFilename, 'algebra_v1.pdf');
        expect(material.versions.first.fileSize, '2048000');
      });
    });

    group('Errores de Quality (QualityError)', () {
      test('Criterio 1: ErrorDto parsea el ejemplo exacto de STALE_REVISION', () {
        final errorJson = {
          'statusCode': 409,
          'code': 'STALE_REVISION',
          'message': 'El material cambió. Vuelve a consultar antes de decidir.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        };

        final error = QualityError.fromJson(errorJson);

        expect(error.statusCode, 409);
        expect(error.code, 'STALE_REVISION');
        expect(error.message, 'El material cambió. Vuelve a consultar antes de decidir.');
        expect(error.requestId, '11111111-1111-4111-8111-111111111111');
        expect(error.field, isNull);
      });

      test('QualityError parsea error con campo field específico', () {
        final errorJson = {
          'statusCode': 400,
          'code': 'VALIDATION_ERROR',
          'message': 'Puntuación fuera del rango permitido.',
          'field': 'score',
          'requestId': '22222222-2222-4222-8222-222222222222',
        };

        final error = QualityError.fromJson(errorJson);

        expect(error.statusCode, 400);
        expect(error.field, 'score');
      });
    });
  });
}
