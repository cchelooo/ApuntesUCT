import 'dart:convert';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Primera parte de #276: solicitudes del único contrato público actual.
/// Las respuestas son el stub; no representan resultados reales de búsqueda.
class SearchRequestAdapter implements HttpClientAdapter {
  SearchRequestAdapter(this.expectedText);
  final String? expectedText;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'query': expectedText,
        'results': [],
        'total': 0,
        'message': DioSearchRepository.stubMessage,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  DioSearchRepository repository(SearchRequestAdapter adapter) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://gateway.example.test/api/v1',
        headers: {'Authorization': 'Bearer existing-session'},
      ),
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioSearchRepository(ApiClient(customDio: dio));
  }

  Future<void> requestPending(Future<Object> request) =>
      expectLater(request, throwsA(isA<SearchContractPendingException>()));

  test(
    'GET Gateway exacto con texto Unicode y sin filtros/paginación inventados',
    () async {
      final adapter = SearchRequestAdapter('álgebra lineal');
      await requestPending(
        repository(adapter)
            .search(const MaterialSearchQuery(text: '  álgebra lineal  ')),
      );
      final req = adapter.requests.single;
      expect(req.method, 'GET');
      expect(
        req.uri.toString(),
        'https://gateway.example.test/api/v1/search?q=%C3%A1lgebra+lineal',
      );
      expect(req.queryParameters, {'q': 'álgebra lineal'});
      expect(req.data, isNull);
      expect(req.headers['Authorization'], 'Bearer existing-session');
    },
  );

  test('caracteres reservados permanecen dentro de q, sin alterar ruta ni parámetros', () async {
    const text = 'redes & q=otro/?#+%';
    final adapter = SearchRequestAdapter(text);
    await requestPending(
      repository(adapter).search(const MaterialSearchQuery(text: text)),
    );
    final uri = adapter.requests.single.uri;
    expect(
      uri.toString(),
      'https://gateway.example.test/api/v1/search?q=redes+%26+q%3Dotro%2F%3F%23%2B%25',
    );
    expect(uri.queryParameters, {'q': text});
    expect(uri.fragment, isEmpty);
    expect(uri.path, '/api/v1/search');
  });

  test(
    'texto y filtros inactivos no se serializan como null o cadenas vacías',
    () async {
      final adapter = SearchRequestAdapter(null);
      await requestPending(
        repository(adapter).search(
          const MaterialSearchQuery(
            text: ' \n ',
            universityId: '',
            careerId: ' ',
            subjectId: '',
            professorId: '  ',
            type: '',
          ),
        ),
      );
      expect(
        adapter.requests.single.uri.toString(),
        'https://gateway.example.test/api/v1/search',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
    },
  );

  final filters = <String, MaterialSearchQuery>{
    'universidad': const MaterialSearchQuery(universityId: 'uct'),
    'carrera': const MaterialSearchQuery(careerId: 'informatica'),
    'asignatura': const MaterialSearchQuery(subjectId: 'algebra'),
    'docente': const MaterialSearchQuery(professorId: 'profesor'),
    'año': const MaterialSearchQuery(year: 2026),
    'tipo': const MaterialSearchQuery(type: 'DOCUMENT'),
    'combinación con texto': const MaterialSearchQuery(
      text: 'álgebra',
      universityId: 'uct',
      careerId: 'informatica',
      subjectId: 'algebra',
      professorId: 'profesor',
      year: 2026,
      type: 'DOCUMENT',
    ),
  };
  for (final entry in filters.entries) {
    test(
      '${entry.key}: no ignora el filtro ni supone un nombre HTTP',
      () async {
        final adapter = SearchRequestAdapter(null);
        await requestPending(repository(adapter).search(entry.value));
        expect(adapter.requests, isEmpty);
      },
    );
  }

  for (final pagination in [(2, 10), (1, 20)]) {
    test(
      'página/límite $pagination espera contrato sin enviar una búsqueda parcial',
      () async {
        final adapter = SearchRequestAdapter(null);
        await requestPending(
          repository(adapter).search(
            const MaterialSearchQuery(text: 'redes'),
            page: pagination.$1,
            pageSize: pagination.$2,
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }

  test(
    'cancelación previa no emite HTTP ni recurre a otros servicios',
    () async {
      final adapter = SearchRequestAdapter('álgebra');
      final token = CancelToken()..cancel('cancelado por usuario');
      await expectLater(
        repository(adapter).search(
          const MaterialSearchQuery(text: 'álgebra'),
          cancelToken: token,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'mensaje',
            contains('cancelada'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );
}
