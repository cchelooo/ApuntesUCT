import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/quality/quality.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_session_fixture.dart';
import '../helpers/gateway_test_transport.dart';

const _materialId = '11111111-2222-4333-8444-555555555555';
const _requestId = '22222222-2222-4222-8222-222222222222';
const _timestamp = '2026-11-26T12:00:00Z';

void main() {
  late ProviderContainer container;
  late MemorySessionStorage storage;
  late SessionController session;
  late AuthSession student;

  setUp(() async {
    storage = MemorySessionStorage();
    container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        apiclientProvider.overrideWith((ref) {
          final client = ApiClient(
            baseUrl: testGatewayUrl,
            session: ref.watch(sessionControllerProvider),
          );
          ref.onDispose(() => client.dio.close(force: true));
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);

    session = container.read(sessionControllerProvider);
    final now = DateTime.now();
    student = AuthSession.fromLogin(loginFixture(now: now), now);
    expect(await session.accept(student, session.beginLogin()), isTrue);
  });

  // Respuestas controladas en el transporte. Dio adjunta la sesión real
  // de Mobile utilizando una credencial sintética que nunca sale a la red.
  GatewayTestTransport useTransport(
    Set<String> methods,
    FutureOr<ResponseBody> Function(RequestOptions) respond,
  ) {
    final transport = GatewayTestTransport(
      respond,
      allowedMethods: methods,
      checkAuthorization: (request) {
        final activeSession = session.current;
        expect(
          request.headers['Authorization'],
          activeSession == null
              ? isNull
              : 'Bearer ${activeSession.accessToken}',
        );
      },
    );
    container.read(apiclientProvider).dio.httpClientAdapter = transport;
    return transport;
  }

  group('Contrato HTTP de Quality', () {
    test(
      'guarda y elimina el mismo favorito sin duplicar el listado',
      () async {
        const favoriteRoute = '/api/v1/quality/materials/$_materialId/favorite';
        const listRoute = '/api/v1/quality/favorites/me';
        const favorite = {
          'id': '44444444-4444-4444-8444-444444444444',
          'materialId': _materialId,
          'createdAt': _timestamp,
          'available': true,
        };
        var saved = false;
        final transport = useTransport({'PUT', 'GET', 'DELETE'}, (request) {
          switch (request.method) {
            case 'PUT':
              expect(request.uri.path, favoriteRoute);
              final status = saved ? 200 : 201;
              saved = true;
              return gatewayJson(favorite, status: status);
            case 'DELETE':
              expect(request.uri.path, favoriteRoute);
              saved = false;
              return ResponseBody.fromString('', 204);
            default:
              expect(request.uri.path, listRoute);
              return gatewayJson({
                'items': [if (saved) favorite],
                'page': 1,
                'pageSize': 20,
                'total': saved ? 1 : 0,
              });
          }
        });
        final repo = container.read(qualityRepositoryProvider);

        final created = await repo.addFavorite(_materialId);
        final repeated = await repo.addFavorite(_materialId);
        expect(repeated.id, created.id);
        final page = await repo.getFavorites();
        expect(page.items.single.id, created.id);
        expect(page.items.single.materialId, _materialId);
        expect(page.total, 1);

        await repo.removeFavorite(_materialId);
        final afterRemoval = await repo.getFavorites();
        expect(afterRemoval.items, isEmpty);
        expect(afterRemoval.total, 0);
        expect(transport.requests.map((request) => request.method), [
          'PUT',
          'PUT',
          'GET',
          'DELETE',
          'GET',
        ]);
        expect(transport.bodies, everyElement(isEmpty));
      },
    );

    test('envía la calificación propia con la sesión compartida', () async {
      const ratingId = '33333333-3333-4333-8333-333333333333';
      final transport = useTransport({'PUT'}, (_) {
        return gatewayJson({
          'id': ratingId,
          'materialId': _materialId,
          'userId': student.user.id,
          'score': 4,
          'comment': 'Útil para repasar',
          'createdAt': _timestamp,
          'updatedAt': _timestamp,
        }, status: 201);
      });
      final repo = container.read(qualityRepositoryProvider);

      final rating = await repo.upsertRating(
        _materialId,
        const RatingUpsert(score: 4, comment: 'Útil para repasar'),
      );

      expect(
        transport.requests.single.uri.toString(),
        '$testGatewayUrl/quality/materials/$_materialId/ratings/me',
      );
      expect(jsonDecode(utf8.decode(transport.bodies.single)), {
        'score': 4,
        'comment': 'Útil para repasar',
      });
      expect(rating.id, ratingId);
      expect(rating.userId, student.user.id);
      expect(rating.score, 4);
      expect(rating.comment, 'Útil para repasar');
    });

    test('lee favoritos paginados con la sesión compartida', () async {
      const favoriteId = '44444444-4444-4444-8444-444444444444';
      final transport = useTransport({'GET'}, (_) {
        return gatewayJson({
          'items': [
            {
              'id': favoriteId,
              'materialId': _materialId,
              'createdAt': _timestamp,
              'available': false,
            },
          ],
          'page': 2,
          'pageSize': 10,
          'total': 11,
        });
      });
      final repo = container.read(qualityRepositoryProvider);

      final page = await repo.getFavorites(page: 2, pageSize: 10);

      expect(
        transport.requests.single.uri,
        Uri.parse('$testGatewayUrl/quality/favorites/me')
            .replace(queryParameters: {'page': '2', 'pageSize': '10'}),
      );
      expect(page.total, 11);
      final favorite = page.items.single;
      expect(favorite.id, favoriteId);
      expect(favorite.materialId, _materialId);
      expect(favorite.available, isFalse);
    });

    test('crea un reporte y lo recupera en el historial propio', () async {
      const reportId = '55555555-5555-4555-8555-555555555555';
      const details = 'El enlace no abre';
      final report = {
        'id': reportId,
        'materialId': _materialId,
        'userId': student.user.id,
        'reason': 'BROKEN_RESOURCE',
        'details': details,
        'status': 'OPEN',
        'resolutionNote': null,
        'createdAt': _timestamp,
        'updatedAt': _timestamp,
      };
      final transport = useTransport({'POST', 'GET'}, (request) {
        if (request.method == 'POST') {
          return gatewayJson(report, status: 201);
        }
        return gatewayJson({
          'items': [report],
          'page': 1,
          'pageSize': 20,
          'total': 1,
        });
      });
      final repo = container.read(qualityRepositoryProvider);

      final created = await repo.createReport(
        _materialId,
        const ReportCreate(
          reason: ReportReason.brokenResource,
          details: details,
        ),
      );
      final history = await repo.getMyReports();

      expect(transport.requests.map((request) => request.uri.path), [
        '/api/v1/quality/materials/$_materialId/reports',
        '/api/v1/quality/reports/me',
      ]);
      expect(
        transport.requests.first.headers['Idempotency-Key'],
        hasLength(36),
      );
      expect(jsonDecode(utf8.decode(transport.bodies.first)), {
        'reason': 'BROKEN_RESOURCE',
        'details': details,
      });
      expect(created.id, reportId);
      expect(history.items.single.id, created.id);
      expect(history.items.single.status, ReportStatus.open);
    });

    test(
      'consulta la confirmación de una decisión con sesión moderadora',
      () async {
        final now = DateTime.now();
        final moderator = AuthSession.fromLogin(
          loginFixture(
            now: now,
            role: 'MODERATOR',
            name: 'Moderador de prueba',
          ),
          now,
        );
        expect(await session.accept(moderator, session.beginLogin()), isTrue);
        const operationId = '66666666-6666-4666-8666-666666666666';
        final operation = {
          'id': operationId,
          'materialId': _materialId,
          'actorId': moderator.user.id,
          'action': 'APPROVE',
          'reason': 'Contenido correcto',
          'expectedRevision': 3,
          'createdAt': _timestamp,
          'updatedAt': _timestamp,
          'failure': null,
        };
        final transport = useTransport({'POST', 'GET'}, (request) {
          if (request.method == 'POST') {
            return gatewayJson({
              ...operation,
              'state': 'PENDING_APPLICATION',
              'result': null,
            }, status: 202);
          }
          return gatewayJson({
            ...operation,
            'state': 'APPLIED',
            'result': {
              'materialId': _materialId,
              'status': 'PUBLISHED',
              'verified': false,
              'revision': 4,
            },
          });
        });
        final repo = container.read(qualityRepositoryProvider);

        final pending = await repo.submitModerationDecision(
          _materialId,
          const ModerationDecisionRequest(
            action: ModerationAction.approve,
            reason: 'Contenido correcto',
            expectedRevision: 3,
          ),
        );
        expect(pending.id, operationId);
        expect(pending.state, ModerationOperationState.pendingApplication);
        expect(pending.result, isNull);
        expect(transport.requests, hasLength(1));

        final applied = await repo.getModerationOperation(pending.id);
        expect(transport.requests.map((request) => request.uri.path), [
          '/api/v1/quality/moderation/materials/$_materialId/decisions',
          '/api/v1/quality/moderation/operations/$operationId',
        ]);
        expect(
          transport.requests.first.headers['Idempotency-Key'],
          hasLength(36),
        );
        expect(jsonDecode(utf8.decode(transport.bodies.first)), {
          'action': 'APPROVE',
          'reason': 'Contenido correcto',
          'expectedRevision': 3,
        });
        expect(applied.id, pending.id);
        expect(applied.actorId, moderator.user.id);
        expect(applied.state, ModerationOperationState.applied);
        expect(applied.result?.materialId, _materialId);
        expect(applied.result?.revision, 4);
      },
    );
  });

  group('Fallos de Quality mediante Gateway', () {
    test(
      'rechaza una lectura protegida sin sesión y sin datos ficticios',
      () async {
        await session.clear();
        final transport = useTransport({'GET'}, (_) {
          return gatewayJson({
            'statusCode': 401,
            'code': 'UNAUTHORIZED',
            'message': 'Inicia sesión para consultar tus favoritos.',
          }, status: 401);
        });
        final repo = container.read(qualityRepositoryProvider);

        await expectLater(
          repo.getFavorites(),
          throwsA(
            isA<QualityApiException>()
                .having((error) => error.statusCode, 'statusCode', 401)
                .having(
                  (error) => error.errorCode,
                  'errorCode',
                  'UNAUTHORIZED',
                ),
          ),
        );

        expect(
          transport.requests.single.uri.path,
          '/api/v1/quality/favorites/me',
        );
        expect(transport.requests.single.headers['Authorization'], isNull);
        expect(session.current, isNull);
        expect(await storage.read(), isNull);
      },
    );

    test('conserva el error de conexión hasta una lectura explícita', () async {
      const favoriteId = '44444444-4444-4444-8444-444444444444';
      var connected = false;
      final transport = useTransport({'GET'}, (request) {
        if (!connected) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'Conexión interrumpida en el transporte de prueba',
          );
        }
        return gatewayJson({
          'items': [
            {
              'id': favoriteId,
              'materialId': _materialId,
              'createdAt': _timestamp,
              'available': true,
            },
          ],
          'page': 1,
          'pageSize': 20,
          'total': 1,
        });
      });
      final repo = container.read(qualityRepositoryProvider);

      await expectLater(
        repo.getFavorites(),
        throwsA(
          isA<QualityApiException>()
              .having((error) => error.statusCode, 'statusCode', isNull)
              .having(
                (error) => error.message,
                'message',
                contains('Verifica tu red'),
              ),
        ),
      );
      expect(transport.requests, hasLength(1));
      expect(session.current, same(student));
      expect(await storage.read(), student.encode());

      connected = true;
      final recovered = await repo.getFavorites();

      expect(transport.requests, hasLength(2));
      expect(transport.requests.last.uri, transport.requests.first.uri);
      expect(recovered.items.single.id, favoriteId);
      expect(recovered.total, 1);
    });

    for (final (status, code, message) in [
      (401, 'UNAUTHORIZED', 'La sesión ya no es válida.'),
      (403, 'FORBIDDEN', 'Se requiere rol de moderador.'),
    ]) {
      test(
        'propaga $status en moderación y aplica el efecto de sesión',
        () async {
          final transport = useTransport({'GET'}, (_) {
            return gatewayJson({
              'statusCode': status,
              'code': code,
              'message': message,
              'requestId': _requestId,
            }, status: status);
          });
          final repo = container.read(qualityRepositoryProvider);

          await expectLater(
            repo.listModerationMaterials(),
            throwsA(
              isA<QualityApiException>()
                  .having((error) => error.statusCode, 'statusCode', status)
                  .having((error) => error.errorCode, 'errorCode', code)
                  .having((error) => error.message, 'message', message)
                  .having((error) => error.requestId, 'requestId', _requestId),
            ),
          );

          expect(
            transport.requests.single.uri.path,
            '/api/v1/quality/moderation/materials',
          );
          if (status == 401) {
            expect(session.current, isNull);
            expect(await storage.read(), isNull);
          } else {
            expect(session.current, same(student));
            expect(await storage.read(), student.encode());
          }
        },
      );
    }

    test('propaga 502 y conserva la clave al reintentar un reporte', () async {
      const reportId = '55555555-5555-4555-8555-555555555555';
      const details = 'El enlace no abre';
      var replayAvailable = false;
      final transport = useTransport({'POST'}, (_) {
        if (!replayAvailable) {
          return gatewayJson({
            'statusCode': 502,
            'code': 'DEPENDENCY_INVALID_RESPONSE',
            'message': 'Quality no está disponible temporalmente.',
            'requestId': _requestId,
          }, status: 502);
        }
        return gatewayJson({
          'id': reportId,
          'materialId': _materialId,
          'userId': student.user.id,
          'reason': 'BROKEN_RESOURCE',
          'details': details,
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': _timestamp,
          'updatedAt': _timestamp,
        }, status: 200);
      });
      final repo = container.read(qualityRepositoryProvider);
      const report = ReportCreate(
        reason: ReportReason.brokenResource,
        details: details,
      );

      await expectLater(
        repo.createReport(_materialId, report),
        throwsA(
          isA<QualityApiException>()
              .having((error) => error.statusCode, 'statusCode', 502)
              .having(
                (error) => error.errorCode,
                'errorCode',
                'DEPENDENCY_INVALID_RESPONSE',
              )
              .having((error) => error.requestId, 'requestId', _requestId)
              .having(
                (error) => error.message,
                'message',
                'Quality no está disponible temporalmente.',
              ),
        ),
      );
      expect(
        transport.requests.single.uri.toString(),
        '$testGatewayUrl/quality/materials/$_materialId/reports',
      );
      final key = transport.requests.single.headers['Idempotency-Key'];
      expect(key, isA<String>().having((value) => value.length, 'length', 36));
      expect(session.current, same(student));

      // El Gateway simula haber perdido la primera respuesta y entrega el
      // reporte original al recibir de nuevo la misma clave y el mismo cuerpo.
      replayAvailable = true;
      final confirmed = await repo.createReport(_materialId, report);

      expect(transport.requests, hasLength(2));
      expect(transport.requests.last.uri, transport.requests.first.uri);
      expect(transport.requests.last.headers['Idempotency-Key'], key);
      expect(jsonDecode(utf8.decode(transport.bodies.first)), {
        'reason': 'BROKEN_RESOURCE',
        'details': details,
      });
      expect(transport.bodies.last, transport.bodies.first);
      expect(confirmed.id, reportId);
      expect(confirmed.status, ReportStatus.open);
    });
  });
}
