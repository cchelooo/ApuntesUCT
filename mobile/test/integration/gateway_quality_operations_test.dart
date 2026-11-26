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
    String method,
    FutureOr<ResponseBody> Function(RequestOptions) respond,
  ) {
    final transport = GatewayTestTransport(
      respond,
      allowedMethods: {method},
      expectedAuthorization: 'Bearer ${student.accessToken}',
    );
    container.read(apiclientProvider).dio.httpClientAdapter = transport;
    return transport;
  }

  group('Contrato HTTP de Quality', () {
    test('envía la calificación propia con la sesión compartida', () async {
      const ratingId = '33333333-3333-4333-8333-333333333333';
      final transport = useTransport('PUT', (_) {
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
      final transport = useTransport('GET', (_) {
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
  });
}
