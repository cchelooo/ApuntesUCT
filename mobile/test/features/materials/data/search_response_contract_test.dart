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

import '../../../helpers/gateway_test_transport.dart';
import '../../../helpers/material_http_adapter.dart';

// Muestra independiente de SearchResponseDto, SearchResultDto y
// SearchSubjectContextDto. No se genera usando el parser de Mobile.
Map<String, dynamic> publicResponse() => jsonDecode(
  File('test/fixtures/materials/gateway_search_page.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> firstResult(Map<String, dynamic> body) =>
    (body['results'] as List).first as Map<String, dynamic>;
Map<String, dynamic> firstContext(Map<String, dynamic> body) =>
    (body['context'] as List).first as Map<String, dynamic>;

void main() {
  const query = MaterialSearchQuery(text: 'álgebra');

  ApiClient client(MaterialHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: testGatewayUrl))
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

  test(
    'adapta results con IDs, nombres, tipo, año y paginación públicos',
    () async {
      final adapter = MaterialHttpAdapter(publicResponse(), status: 200);
      final result = await DioSearchRepository(client(adapter)).search(query);
      expect(result.page, 1);
      expect(result.pageSize, 10);
      expect(result.total, 1);
      expect(result.hasNextPage, isFalse);
      final material = result.items.single;
      expect(material.id, '55555555-5555-4555-8555-555555555555');
      expect(material.title, 'Guía de álgebra');
      expect(material.description, 'Ejercicios resueltos');
      expect(material.materialType, 'DOCUMENT');
      expect(material.academicYear, 2026);
      expect(material.university?.id, '11111111-1111-4111-8111-111111111111');
      expect(material.university?.name, 'Universidad de prueba');
      expect(material.career?.id, '22222222-2222-4222-8222-222222222222');
      expect(material.subject?.id, '33333333-3333-4333-8333-333333333333');
      expect(material.subjectName, 'Álgebra');
      expect(
        material.professorReference?.id,
        '44444444-4444-4444-8444-444444444444',
      );
      expect(material.createdAt, DateTime.utc(2026, 10, 30, 12));
    },
  );

  test(
    'cero resultados es AsyncData vacío y no una integración pendiente',
    () async {
      final body = publicResponse()
        ..['results'] = []
        ..['context'] = []
        ..['total'] = 0;
      final container = containerFor(MaterialHttpAdapter(body, status: 200));
      final controller = container.read(
        materialSearchControllerProvider.notifier,
      );
      await controller.search(query);
      final state = container.read(materialSearchControllerProvider);
      expect(state.result!.hasError, isFalse);
      expect(state.result!.requireValue.total, 0);
      expect(state.items, isEmpty);
      expect(state.result!.requireValue.hasNextPage, isFalse);
      expect(state.isLoadingMore, isFalse);
    },
  );

  test(
    'acepta null explícito en campos anulables y campos nuevos adicionales',
    () async {
      final body = publicResponse()..['query'] = null;
      final result = firstResult(body);
      for (final field in [
        'description',
        'materialType',
        'academicYear',
        'subjectId',
        'careerId',
        'universityId',
        'professorId',
        'subjectName',
        'careerName',
        'universityName',
        'createdAt',
        'updatedAt',
      ]) {
        result[field] = null;
      }
      final context = firstContext(body);
      for (final field in [
        'subjectCode',
        'semester',
        'careerId',
        'careerName',
        'universityId',
        'universityName',
      ]) {
        context[field] = null;
      }
      body['newOptionalMetadata'] = 'compatible';
      final page = await DioSearchRepository(
        client(MaterialHttpAdapter(body, status: 200)),
      ).search(const MaterialSearchQuery());
      expect(page.items.single.id, '55555555-5555-4555-8555-555555555555');
      expect(page.items.single.academicYear, isNull);
    },
  );

  final mutations = <String, void Function(Map<String, dynamic>)>{
    for (final field in [
      'query',
      'page',
      'pageSize',
      'total',
      'results',
      'context',
    ])
      'raíz sin $field': (body) => body.remove(field),
    for (final field in [
      'id',
      'title',
      'description',
      'materialType',
      'academicYear',
      'verified',
      'subjectId',
      'careerId',
      'universityId',
      'professorId',
      'subjectName',
      'careerName',
      'universityName',
      'createdAt',
      'updatedAt',
    ])
      'resultado sin $field': (body) => firstResult(body).remove(field),
    for (final field in [
      'subjectId',
      'subjectName',
      'subjectCode',
      'semester',
      'careerId',
      'careerName',
      'universityId',
      'universityName',
      'professors',
    ])
      'contexto sin $field': (body) => firstContext(body).remove(field),
    for (final field in ['id', 'name'])
      'profesor sin $field': (body) =>
          ((firstContext(body)['professors'] as List).first as Map).remove(
            field,
          ),
    'query numérica': (body) => body['query'] = 123,
    'page como cadena': (body) => body['page'] = '1',
    'page no corresponde a la solicitud': (body) => body['page'] = 2,
    'pageSize como cadena': (body) => body['pageSize'] = '10',
    'pageSize no corresponde a la solicitud': (body) => body['pageSize'] = 20,
    'total como cadena': (body) => body['total'] = '1',
    'total fraccionario': (body) => body['total'] = 0.5,
    'total negativo': (body) => body['total'] = -1,
    'results null': (body) => body['results'] = null,
    'results como objeto': (body) => body['results'] = <String, dynamic>{},
    'results renombrado a items': (body) =>
        body['items'] = body.remove('results'),
    'results contiene un número': (body) => body['results'] = [7],
    'context null': (body) => body['context'] = null,
    'context contiene un número': (body) => body['context'] = [7],
    'id en blanco': (body) => firstResult(body)['id'] = ' ',
    'title en blanco': (body) => firstResult(body)['title'] = '\n',
    'verified como cadena': (body) => firstResult(body)['verified'] = 'true',
    'year como cadena': (body) => firstResult(body)['academicYear'] = '2026',
    'year fuera de contrato': (body) =>
        firstResult(body)['academicYear'] = 2100,
    'fecha inválida': (body) => firstResult(body)['createdAt'] = 'fecha',
    'referencia numérica': (body) => firstResult(body)['subjectId'] = 123,
    'professors como objeto': (body) => firstContext(body)['professors'] = {},
    'semester fuera de contrato': (body) => firstContext(body)['semester'] = 13,
  };
  for (final (name, mutate) in mutations.entries.map(
    (entry) => (entry.key, entry.value),
  )) {
    test('cambio contractual $name llega como error al provider', () async {
      final body = publicResponse();
      mutate(body);
      final adapter = MaterialHttpAdapter(body, status: 200);
      final container = containerFor(adapter);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(query);
      final state = container.read(materialSearchControllerProvider);
      expect(state.result!.asData, isNull);
      expect(
        state.result!.error,
        isA<ApiException>()
            .having(
              (e) => e.message,
              'mensaje',
              'Search devolvió una respuesta inválida.',
            )
            .having((e) => e.data, 'causa', isA<FormatException>()),
      );
      expect(state.items, isEmpty);
      expect(state.isLoadingMore, isFalse);
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final body in [null, [], 'respuesta', 7]) {
    test('raíz inválida $body no se convierte en búsqueda vacía', () async {
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

  test('502 público conserva código, cuerpo y mensaje hasta el provider y se recupera', () async {
    var unavailable = true;
    const errorBody = {
      'statusCode': 502,
      'message': 'Search Service no disponible',
    };
    final transport = GatewayTestTransport((request) {
      expect(
        request.uri.toString(),
        '$testGatewayUrl/search?q=%C3%A1lgebra&page=1&pageSize=10',
      );
      return unavailable
          ? gatewayJson(errorBody, status: 502)
          : gatewayJson(publicResponse());
    });
    final container = gatewayTestContainer(transport);
    final controller = container.read(
      materialSearchControllerProvider.notifier,
    );
    await controller.search(query);
    final failed = container.read(materialSearchControllerProvider);
    expect(failed.result!.asData, isNull);
    expect(
      failed.result!.error,
      isA<ApiException>()
          .having((e) => e.statusCode, 'HTTP', 502)
          .having(
            (e) => e.message,
            'mensaje útil',
            'Search Service no disponible',
          )
          .having((e) => e.data, 'cuerpo público', errorBody),
    );
    expect(failed.items, isEmpty);
    unavailable = false;
    await controller.search(query);
    final recovered = container.read(materialSearchControllerProvider);
    expect(recovered.result!.hasError, isFalse);
    expect(recovered.items.single.title, 'Guía de álgebra');
    expect(transport.requests, hasLength(2));
  });

  for (final failure in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.cancel,
  ]) {
    test('$failure es un error utilizable sin consulta de respaldo', () async {
      final adapter = MaterialHttpAdapter(null, failure: failure);
      final container = containerFor(adapter);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(query);
      final state = container.read(materialSearchControllerProvider);
      expect(
        state.result!.error,
        isA<ApiException>().having((e) => e.message, 'mensaje', isNotEmpty),
      );
      expect(state.result!.asData, isNull);
      expect(state.items, isEmpty);
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
    'stub histórico se distingue del contrato actual y de cero resultados',
    () async {
      const legacy = {
        'query': 'álgebra',
        'results': [],
        'total': 0,
        'message': 'Search Service inicializado correctamente. Búsqueda desacoplada lista para Semana 3.',
      };
      await expectLater(
        DioSearchRepository(client(MaterialHttpAdapter(legacy, status: 200)))
            .search(query),
        throwsA(
          isA<SearchContractPendingException>().having(
            (e) => e.data,
            'respuesta histórica',
            legacy,
          ),
        ),
      );
    },
  );
}
