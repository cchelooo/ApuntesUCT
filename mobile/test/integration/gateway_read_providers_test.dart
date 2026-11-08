import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_catalog_selectors_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_detail_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_gateway_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gateway_test_transport.dart';
import '../helpers/gateway_contract_fixtures.dart';

void main() {
  group('Gateway → Catalog → providers de selectores', () {
    test('las asignaturas de Discovery provienen de Catalog, sin fixtures implícitos', () async {
      final transport = GatewayTestTransport((request) {
        expect(request.uri.toString(), '$testGatewayUrl/catalog/subjects');
        return gatewayJson(
          catalogResponses['$testGatewayUrl/catalog/subjects?careerId=$careerId'],
        );
      });
      final container = gatewayTestContainer(transport);
      expect(await container.read(availableSubjectsProvider.future), ['Redes']);
      expect(transport.requests, hasLength(1));
    });
    test('recorre los cuatro niveles con sus UUID y URI completas', () async {
      final gate = Completer<void>();
      final transport = GatewayTestTransport((request) async {
        await gate.future;
        final uri = request.uri.toString();
        expect(catalogResponses, contains(uri));
        return gatewayJson(catalogResponses[uri]);
      });
      final container = gatewayTestContainer(transport);
      final subscription = container.listen(
        uploadUniversitiesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(container.read(uploadUniversitiesProvider).isLoading, isTrue);
      gate.complete();

      final universities = await container.read(
        uploadUniversitiesProvider.future,
      );
      final careers = await container.read(
        uploadCareersProvider(universities.single.id).future,
      );
      final subjects = await container.read(
        uploadSubjectsProvider(careers.single.id).future,
      );
      final professors = await container.read(
        uploadProfessorsProvider(subjects.single.id).future,
      );

      expect(
        container.read(uploadUniversitiesProvider).requireValue,
        universities,
      );
      expect(careers.single.universityId, universityId);
      expect(subjects.single.id, subjectId);
      expect(professors.single.id, professorId);
      expect(professors.single.email, 'docente@example.test');
      expect(
        transport.requests.map((r) => r.uri.toString()),
        catalogResponses.keys.toList(),
      );
    });

    test(
      'sin padre los niveles hijos resuelven vacío sin emitir HTTP',
      () async {
        final transport = GatewayTestTransport(
          (_) => throw StateError('Sin red'),
        );
        final container = gatewayTestContainer(transport);
        expect(
          await container.read(uploadCareersProvider(null).future),
          isEmpty,
        );
        expect(
          await container.read(uploadSubjectsProvider(null).future),
          isEmpty,
        );
        expect(
          await container.read(uploadProfessorsProvider(null).future),
          isEmpty,
        );
        expect(transport.requests, isEmpty);
      },
    );

    test(
      'una lista vacía válida llega como datos, sin activar un mock',
      () async {
        final transport = GatewayTestTransport((request) {
          expect(
            request.uri.toString(),
            '$testGatewayUrl/catalog/careers?universityId=$universityId',
          );
          return gatewayJson([]);
        });
        final container = gatewayTestContainer(transport);
        final provider = uploadCareersProvider(universityId);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        expect(await container.read(provider.future), isEmpty);
        expect(container.read(provider).hasError, isFalse);
        expect(container.read(provider).requireValue, isEmpty);
        expect(transport.requests, hasLength(1));
      },
    );

    test(
      '502 de asignaturas conserva el mensaje y permite reintento aislado',
      () async {
        var subjectCalls = 0;
        const message = 'Catalog no pudo consultar las asignaturas';
        final transport = GatewayTestTransport((request) {
          if (request.path == '/catalog/subjects' && ++subjectCalls == 1) {
            return gatewayJson({
              'statusCode': 502,
              'message': message,
            }, status: 502);
          }
          final uri = request.uri.toString();
          expect(catalogResponses, contains(uri));
          return gatewayJson(catalogResponses[uri]);
        });
        final container = gatewayTestContainer(transport);
        final careersProvider = uploadCareersProvider(universityId);
        final subjectsProvider = uploadSubjectsProvider(careerId);
        final universitiesSub = container.listen(
          uploadUniversitiesProvider,
          (_, _) {},
        );
        final careersSub = container.listen(careersProvider, (_, _) {});
        final subjectsSub = container.listen(subjectsProvider, (_, _) {});
        addTearDown(universitiesSub.close);
        addTearDown(careersSub.close);
        addTearDown(subjectsSub.close);
        await container.read(uploadUniversitiesProvider.future);
        await container.read(careersProvider.future);
        await expectLater(
          container.read(subjectsProvider.future),
          throwsA(
            isA<DioException>().having(
              (e) => (e.error as ApiException).message,
              'mensaje',
              message,
            ),
          ),
        );
        expect(container.read(subjectsProvider).hasError, isTrue);
        expect(container.read(uploadUniversitiesProvider).hasValue, isTrue);
        expect(
          container.read(careersProvider).requireValue.single.id,
          careerId,
        );

        container.invalidate(subjectsProvider);
        expect(
          (await container.read(subjectsProvider.future)).single.id,
          subjectId,
        );
        expect(container.read(subjectsProvider).hasError, isFalse);
        expect(subjectCalls, 2);
        expect(transport.requests, hasLength(4));
      },
    );
  });

  group('Gateway → Material → providers de lectura', () {
    test(
      'dos páginas conservan sus resultados y metadatos independientes',
      () async {
        final gate = Completer<void>();
        final transport = GatewayTestTransport((request) async {
          final page = request.queryParameters['page'] as int;
          expect(
            request.uri.toString(),
            '$testGatewayUrl/materials?page=$page&pageSize=10',
          );
          await gate.future;
          return gatewayJson(pageResponse(page));
        });
        final container = gatewayTestContainer(transport);
        final firstSub = container.listen(materialListProvider(1), (_, _) {});
        final secondSub = container.listen(materialListProvider(2), (_, _) {});
        addTearDown(firstSub.close);
        addTearDown(secondSub.close);
        expect(container.read(materialListProvider(1)).isLoading, isTrue);
        expect(container.read(materialListProvider(2)).isLoading, isTrue);
        gate.complete();

        final first = await container.read(materialListProvider(1).future);
        final second = await container.read(materialListProvider(2).future);
        expect(first.items, hasLength(10));
        expect(first.page, 1);
        expect(first.pageSize, 10);
        expect(first.total, 11);
        expect(first.hasNextPage, isTrue);
        expect(second.items.single.id, materialSummary(11)['id']);
        expect(second.page, 2);
        expect(second.total, 11);
        expect(second.hasNextPage, isFalse);
        expect(
          container.read(materialListProvider(1)).requireValue,
          same(first),
        );
        expect(transport.requests, hasLength(2));
      },
    );

    test('cero materiales es AsyncData vacío con metadatos válidos', () async {
      final transport = GatewayTestTransport((request) {
        expect(
          request.uri.toString(),
          '$testGatewayUrl/materials?page=1&pageSize=10',
        );
        return gatewayJson({
          'items': [],
          'page': 1,
          'pageSize': 10,
          'total': 0,
        });
      });
      final container = gatewayTestContainer(transport);
      final subscription = container.listen(materialListProvider(1), (_, _) {});
      addTearDown(subscription.close);
      final result = await container.read(materialListProvider(1).future);
      expect(result.items, isEmpty);
      expect(result.total, 0);
      expect(result.hasNextPage, isFalse);
      expect(container.read(materialListProvider(1)).hasError, isFalse);
      expect(transport.requests, hasLength(1));
    });

    for (final status in [401, 404, 500, 502]) {
      test(
        'HTTP $status llega al provider con mensaje y cuerpo originales',
        () async {
          final body = {
            'statusCode': status,
            'message': 'Error público $status',
          };
          final transport = GatewayTestTransport((request) {
            expect(
              request.uri.toString(),
              '$testGatewayUrl/materials?page=1&pageSize=10',
            );
            return gatewayJson(body, status: status);
          });
          final container = gatewayTestContainer(transport);
          final provider = materialListProvider(1);
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          await expectLater(
            container.read(provider.future),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.statusCode, 'HTTP', status)
                  .having((e) => e.message, 'mensaje', body['message'])
                  .having((e) => e.data, 'cuerpo', body),
            ),
          );
          final state = container.read(provider);
          expect(state.hasError, isTrue);
          expect(state.hasValue, isFalse);
          expect((state.error as ApiException).message, body['message']);
          expect(transport.requests, hasLength(1));
        },
      );
    }

    test(
      'timeout es AsyncError y un reintento explícito recupera los datos',
      () async {
        var attempt = 0;
        final transport = GatewayTestTransport((request) {
          expect(
            request.uri.toString(),
            '$testGatewayUrl/materials?page=1&pageSize=10',
          );
          if (++attempt == 1) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return gatewayJson(pageResponse(1));
        });
        final container = gatewayTestContainer(transport);
        final provider = materialListProvider(1);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await expectLater(
          container.read(provider.future),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'mensaje',
              contains('Tiempo de espera'),
            ),
          ),
        );
        expect(container.read(provider).hasError, isTrue);
        container.invalidate(provider);
        final recovered = await container.read(provider.future);
        expect(recovered.items, hasLength(10));
        expect(container.read(provider).hasError, isFalse);
        expect(transport.requests, hasLength(2));
      },
    );

    test(
      'detalle conserva la versión pública y la ruta completa por ID',
      () async {
        final body = jsonDecode(
          File('test/fixtures/materials/gateway_detail.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>;
        final transport = GatewayTestTransport((request) {
          expect(
            request.uri.toString(),
            '$testGatewayUrl/materials/${body['id']}',
          );
          return gatewayJson(body);
        });
        final container = gatewayTestContainer(transport);
        final provider = materialDetailProvider(body['id'] as String);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        expect(container.read(provider).isLoading, isTrue);
        final result = await container.read(provider.future);
        expect(result.summary.id, body['id']);
        expect(result.summary.subject!.id, body['subjectId']);
        expect(result.currentVersion!.id, body['currentVersion']['id']);
        expect(result.currentVersion!.versionNumber, 2);
        expect(result.currentVersion!.fileSizeBytes, 12345);
        expect(result.currentVersion!.storageKey, isNull);
        expect(container.read(provider).requireValue, same(result));
        expect(transport.requests, hasLength(1));
      },
    );
  });
}
