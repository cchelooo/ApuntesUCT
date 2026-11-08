import 'dart:async';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_search_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gateway_contract_fixtures.dart';
import '../helpers/gateway_test_transport.dart';

void main() {
  test(
    'texto Unicode, todos los filtros, orden y segunda página por Gateway',
    () async {
      final gate = Completer<void>();
      final transport = GatewayTestTransport((request) async {
        expect(request.uri.origin + request.uri.path, '$testGatewayUrl/search');
        expect(request.queryParameters, {
          'q': 'álgebra & redes',
          'universityId': universityId,
          'careerId': careerId,
          'subjectId': subjectId,
          'professorId': professorId,
          'year': 2026,
          'type': 'DOCUMENT',
          'sortBy': 'title',
          'order': 'asc',
          'page': transportPage(request),
          'pageSize': 10,
        });
        await gate.future;
        return gatewayJson(
          searchResponse(
            query: 'álgebra & redes',
            page: transportPage(request),
          ),
        );
      });
      final container = gatewayTestContainer(transport);
      final notifier = container.read(
        materialSearchControllerProvider.notifier,
      );
      final first = notifier.search(
        const MaterialSearchQuery(
          text: '  álgebra & redes  ',
          universityId: universityId,
          careerId: careerId,
          subjectId: subjectId,
          professorId: professorId,
          year: 2026,
          type: 'DOCUMENT',
          sortBy: 'title',
          order: 'asc',
        ),
      );
      expect(
        container.read(materialSearchControllerProvider).result!.isLoading,
        isTrue,
      );
      gate.complete();
      await first;
      expect(
        container.read(materialSearchControllerProvider).items,
        hasLength(10),
      );
      await notifier.loadMore();
      final state = container.read(materialSearchControllerProvider);
      expect(state.items, hasLength(11));
      expect(state.result!.requireValue.page, 2);
      expect(state.result!.requireValue.total, 11);
      expect(state.pageError, isNull);
      expect(transport.requests.map((r) => r.uri.queryParameters['page']), [
        '1',
        '2',
      ]);
      expect(
        transport.requests.first.uri.queryParameters['q'],
        'álgebra & redes',
      );
      expect(transport.requests.first.uri.fragment, isEmpty);
    },
  );

  final filters = <(MaterialSearchQuery, Map<String, Object>)>[
    (
      const MaterialSearchQuery(universityId: universityId),
      {'universityId': universityId},
    ),
    (
      const MaterialSearchQuery(universityId: universityId, careerId: careerId),
      {'universityId': universityId, 'careerId': careerId},
    ),
    (
      const MaterialSearchQuery(
        universityId: universityId,
        careerId: careerId,
        subjectId: subjectId,
      ),
      {
        'universityId': universityId,
        'careerId': careerId,
        'subjectId': subjectId,
      },
    ),
    (const MaterialSearchQuery(year: 2026), {'year': 2026}),
    (const MaterialSearchQuery(type: 'DOCUMENT'), {'type': 'DOCUMENT'}),
  ];
  for (var i = 0; i < filters.length; i++) {
    test(
      'filtro ${i + 1} conserva parámetros y cero resultados como datos',
      () async {
        final (query, parameters) = filters[i];
        final transport = GatewayTestTransport((request) {
          expect(request.uri.path, '/api/v1/search');
          expect(request.queryParameters, {
            ...parameters,
            'page': 1,
            'pageSize': 10,
          });
          return gatewayJson({
            ...searchResponse(query: null, total: 0),
            'context': [],
          });
        });
        final container = gatewayTestContainer(transport);
        await container
            .read(materialSearchControllerProvider.notifier)
            .search(query);
        final state = container.read(materialSearchControllerProvider);
        expect(state.result!.hasError, isFalse);
        expect(state.items, isEmpty);
        expect(state.result!.requireValue.total, 0);
        expect(transport.requests, hasLength(1));
      },
    );
  }

  test(
    'omite espacios en texto y filtros sin convertirlos en valores HTTP',
    () async {
      final transport = GatewayTestTransport((request) {
        expect(request.queryParameters, {'page': 1, 'pageSize': 10});
        return gatewayJson({
          ...searchResponse(query: null, total: 0),
          'context': [],
        });
      });
      final container = gatewayTestContainer(transport);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(
            const MaterialSearchQuery(
              text: '  ',
              universityId: ' ',
              careerId: '',
              subjectId: '\n',
              professorId: ' ',
              type: ' ',
            ),
          );
      expect(
        container.read(materialSearchControllerProvider).result!.hasError,
        isFalse,
      );
    },
  );

  for (final malformed in <Object?>[
    null,
    [],
    {...searchResponse(), 'page': '1'},
    {...searchResponse(), 'page': 2},
    {...searchResponse()}..remove('context'),
    {
      ...searchResponse(),
      'results': [
        {'id': 'incompleto'},
      ],
    },
  ]) {
    test(
      'DTO inválido ${malformed.runtimeType} llega como error del provider',
      () async {
        final transport = GatewayTestTransport((_) => gatewayJson(malformed));
        final container = gatewayTestContainer(transport);
        await container
            .read(materialSearchControllerProvider.notifier)
            .search(const MaterialSearchQuery(text: 'álgebra'));
        final state = container.read(materialSearchControllerProvider);
        expect(state.result!.error, isA<ApiException>());
        expect(state.items, isEmpty);
      },
    );
  }

  test(
    '502 de la segunda página conserva los resultados y el mensaje útil',
    () async {
      final transport = GatewayTestTransport((request) {
        if (transportPage(request) == 1) return gatewayJson(searchResponse());
        return gatewayJson({
          'statusCode': 502,
          'message': 'Search no está disponible',
        }, status: 502);
      });
      final container = gatewayTestContainer(transport);
      final notifier = container.read(
        materialSearchControllerProvider.notifier,
      );
      await notifier.search(const MaterialSearchQuery(text: 'álgebra'));
      await notifier.loadMore();
      final state = container.read(materialSearchControllerProvider);
      expect(state.items, hasLength(10));
      expect(state.result!.requireValue.page, 1);
      expect(state.isLoadingMore, isFalse);
      expect(
        state.pageError,
        isA<ApiException>().having(
          (e) => e.message,
          'mensaje',
          'Search no está disponible',
        ),
      );
      expect(transport.requests, hasLength(2));
    },
  );

  test('timeout de Search no se convierte en búsqueda vacía exitosa', () async {
    final transport = GatewayTestTransport(
      (request) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final container = gatewayTestContainer(transport);
    await container
        .read(materialSearchControllerProvider.notifier)
        .search(const MaterialSearchQuery(text: 'redes'));
    expect(
      container.read(materialSearchControllerProvider).result!.error,
      isA<ApiException>().having(
        (e) => e.message,
        'mensaje',
        contains('Tiempo de espera'),
      ),
    );
  });

  test(
    'ordenamientos públicos se transmiten sin ordenar fixtures en Mobile',
    () async {
      for (final field in ['createdAt', 'title', 'year']) {
        for (final order in ['asc', 'desc']) {
          final transport = GatewayTestTransport((request) {
            expect(request.queryParameters, {
              'sortBy': field,
              'order': order,
              'page': 1,
              'pageSize': 10,
            });
            return gatewayJson({
              ...searchResponse(query: null, total: 0),
              'context': [],
            });
          });
          final container = gatewayTestContainer(transport);
          await container
              .read(materialSearchControllerProvider.notifier)
              .search(MaterialSearchQuery(sortBy: field, order: order));
          expect(
            container.read(materialSearchControllerProvider).result!.hasError,
            isFalse,
          );
          expect(transport.requests, hasLength(1));
        }
      }
    },
  );

  test('una respuesta HTTP anterior no reemplaza los resultados de la consulta nueva', () async {
    final gate = Completer<void>();
    final transport = GatewayTestTransport((request) async {
      if (request.queryParameters['q'] == 'primera') {
        await gate.future;
        return gatewayJson(searchResponse(query: 'primera', total: 1));
      }
      final second = searchResponse(query: 'segunda', total: 1);
      (second['results'] as List).single['id'] = materialSummary(2)['id'];
      return gatewayJson(second);
    });
    final container = gatewayTestContainer(transport);
    final notifier = container.read(materialSearchControllerProvider.notifier);
    final previous = notifier.search(
      const MaterialSearchQuery(text: 'primera'),
    );
    await notifier.search(const MaterialSearchQuery(text: 'segunda'));
    final newest = container.read(materialSearchControllerProvider);
    expect(newest.items.single.id, materialSummary(2)['id']);
    gate.complete();
    await previous;
    expect(
      container.read(materialSearchControllerProvider).query.text,
      'segunda',
    );
    expect(
      container.read(materialSearchControllerProvider).items.single.id,
      newest.items.single.id,
    );
    expect(transport.requests, hasLength(2));
  });
}

int transportPage(RequestOptions request) =>
    request.queryParameters['page'] as int;
