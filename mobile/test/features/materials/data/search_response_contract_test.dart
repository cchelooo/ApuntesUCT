import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_search_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_http_adapter.dart';

// Fuente: SearchController.search de backend/search-service (stub publicado).
// El fixture es independiente de las constantes del adaptador: un cambio en
// Mobile no debe modificar simultáneamente la respuesta esperada del servidor.
Map<String, dynamic> stub() => jsonDecode(
  File('test/fixtures/materials/gateway_search_stub.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  ApiClient client(MaterialHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return ApiClient(customDio: dio);
  }

  ProviderContainer containerFor(MaterialHttpAdapter adapter) {
    final container = ProviderContainer(
      overrides: [apiclientProvider.overrideWithValue(client(adapter))],
    );
    addTearDown(container.dispose);
    return container;
  }

  const query = MaterialSearchQuery(text: 'álgebra');

  test(
    'results vacío del stub mantiene integración pendiente en la interfaz',
    () async {
      final body = stub();
      final adapter = MaterialHttpAdapter(body, status: 200);
      final container = containerFor(adapter);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(query);
      final state = container.read(materialSearchControllerProvider);
      expect(state.result!.asData, isNull);
      expect(
        state.result!.asError!.error,
        isA<SearchContractPendingException>().having(
          (e) => e.data,
          'respuesta pública',
          body,
        ),
      );
      expect(state.isLoadingMore, isFalse);
      await container
          .read(materialSearchControllerProvider.notifier)
          .loadMore();
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'respuesta sin q exige query null, conservando el estado pendiente',
    () async {
      final body = stub()..['query'] = null;
      await expectLater(
        DioSearchRepository(client(MaterialHttpAdapter(body, status: 200)))
            .search(const MaterialSearchQuery()),
        throwsA(isA<SearchContractPendingException>()),
      );
    },
  );

  // No hay un DTO real de resultados: cualquier evolución desconocida se
  // presenta como error, en vez de producir materiales o páginas inventadas.
  final mutations = <String, void Function(Map<String, dynamic>)>{
    for (final field in ['query', 'results', 'total', 'message'])
      'sin $field': (body) => body.remove(field),
    'query de otra consulta': (body) => body['query'] = 'otro texto',
    'query numérica': (body) => body['query'] = 123,
    'results null': (body) => body['results'] = null,
    'results como objeto': (body) => body['results'] = <String, dynamic>{},
    'results con DTO no acordado': (body) => body['results'] = [
      {'id': 'material'},
    ],
    'total como cadena': (body) => body['total'] = '0',
    'total fraccionario': (body) => body['total'] = 0.5,
    'total negativo': (body) => body['total'] = -1,
    'total incompatible con stub': (body) => body['total'] = 1,
    'message de otro contrato': (body) => body['message'] = 'Respuesta nueva',
    'results renombrado a items': (body) =>
        body['items'] = body.remove('results'),
  };
  for (final entry in mutations.entries) {
    test('cambio contractual ${entry.key} produce error visible', () async {
      final body = stub();
      entry.value(body);
      final adapter = MaterialHttpAdapter(body, status: 200);
      final container = containerFor(adapter);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(query);
      final result = container.read(materialSearchControllerProvider).result!;
      expect(result.asData, isNull);
      expect(
        result.asError!.error,
        isNot(isA<SearchContractPendingException>()),
      );
      expect(
        result.asError!.error,
        isA<ApiException>()
            .having((e) => e.message, 'mensaje', contains('incompatible'))
            .having((e) => e.data, 'causa', isA<FormatException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  }
  for (final body in [null, [], 'respuesta', 7]) {
    test('respuesta raíz $body no se convierte en página vacía', () async {
      await expectLater(
        DioSearchRepository(client(MaterialHttpAdapter(body, status: 200)))
            .search(query),
        throwsA(
          isA<ApiException>().having(
            (e) => e.data,
            'causa',
            isA<FormatException>(),
          ),
        ),
      );
    });
  }

  test('502 público del Gateway conserva código/cuerpo/mensaje hasta la interfaz y permite reintento', () async {
    // Fuente: backend/api-gateway/src/modules/proxy/service-proxy.ts.
    final body = {'statusCode': 502, 'message': 'Search Service no disponible'};
    final adapter = MaterialHttpAdapter(body, status: 502);
    final container = containerFor(adapter);
    final controller = container.read(
      materialSearchControllerProvider.notifier,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await controller.search(query);
      final state = container.read(materialSearchControllerProvider);
      expect(
        state.result!.asError!.error,
        isA<ApiException>()
            .having((e) => e.statusCode, 'HTTP', 502)
            .having(
              (e) => e.message,
              'mensaje útil',
              'Search Service no disponible',
            )
            .having((e) => e.data, 'cuerpo', body),
      );
      expect(state.isLoadingMore, isFalse);
      expect(state.items, isEmpty);
      expect(adapter.requests, hasLength(attempt + 1));
    }
    expect(
      adapter.requests.map((req) => req.uri.toString()),
      everyElement('https://gateway.example.test/api/v1/search?q=%C3%A1lgebra'),
    );
  });

  for (final failure in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.cancel,
  ]) {
    test(
      '$failure produce error utilizable sin consulta de respaldo',
      () async {
        final adapter = MaterialHttpAdapter(null, failure: failure);
        final container = containerFor(adapter);
        await container
            .read(materialSearchControllerProvider.notifier)
            .search(query);
        final state = container.read(materialSearchControllerProvider);
        expect(
          state.result!.asError!.error,
          isA<ApiException>().having((e) => e.message, 'mensaje', isNotEmpty),
        );
        expect(state.result!.asData, isNull);
        expect(adapter.requests, hasLength(1));
      },
    );
  }
}
