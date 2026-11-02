import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_http_adapter.dart';

// SearchQueryDto es la fuente de nombres, jerarquía, enums y límites.
// El JSON es una muestra independiente del DTO público de respuesta.
const university = '11111111-1111-4111-8111-111111111111';
const career = '22222222-2222-4222-8222-222222222222';
const subject = '33333333-3333-4333-8333-333333333333';
const professor = '44444444-4444-4444-8444-444444444444';
const gateway = 'https://gateway.example.test/api/v1';

Map<String, dynamic> response({
  String? query = 'álgebra',
  int page = 1,
  int pageSize = 10,
}) {
  final body = jsonDecode(
    File('test/fixtures/materials/gateway_search_page.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    ...body,
    'query': query,
    'page': page,
    'pageSize': pageSize,
    'total': (page - 1) * pageSize + 1,
  };
}

void main() {
  DioSearchRepository repository(MaterialHttpAdapter adapter) {
    final dio = Dio(
      BaseOptions(
        baseUrl: gateway,
        headers: {'Authorization': 'Bearer test-session-placeholder'},
      ),
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioSearchRepository(ApiClient(customDio: dio));
  }

  test(
    'GET exacto por Gateway con Unicode, paginación y sesión existente',
    () async {
      final adapter = MaterialHttpAdapter(response(), status: 200);
      await repository(adapter)
          .search(const MaterialSearchQuery(text: '  álgebra  '));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(
        request.uri.toString(),
        '$gateway/search?q=%C3%A1lgebra&page=1&pageSize=10',
      );
      expect(request.queryParameters, {
        'q': 'álgebra',
        'page': 1,
        'pageSize': 10,
      });
      expect(request.data, isNull);
      expect(
        request.headers['Authorization'],
        'Bearer test-session-placeholder',
      );
    },
  );

  test('caracteres reservados no alteran ruta, fragmento ni otros parámetros', () async {
    const text = 'redes & q=otro/?#+%';
    final adapter = MaterialHttpAdapter(response(query: text), status: 200);
    await repository(adapter).search(const MaterialSearchQuery(text: text));
    final uri = adapter.requests.single.uri;
    expect(
      uri.toString(),
      '$gateway/search?q=redes+%26+q%3Dotro%2F%3F%23%2B%25&page=1&pageSize=10',
    );
    expect(uri.path, '/api/v1/search');
    expect(uri.fragment, isEmpty);
    expect(uri.queryParameters, {'q': text, 'page': '1', 'pageSize': '10'});
  });

  test(
    'omite texto y filtros vacíos, conservando paginación explícita',
    () async {
      final adapter = MaterialHttpAdapter(response(query: null), status: 200);
      await repository(adapter).search(
        const MaterialSearchQuery(
          text: ' \n ',
          universityId: '',
          careerId: ' ',
          subjectId: '',
          professorId: '  ',
          type: '',
          sortBy: ' ',
          order: '',
        ),
      );
      expect(
        adapter.requests.single.uri.toString(),
        '$gateway/search?page=1&pageSize=10',
      );
      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'pageSize': 10,
      });
    },
  );

  final filters = <(String, MaterialSearchQuery, Map<String, dynamic>)>[
    (
      'universidad',
      const MaterialSearchQuery(universityId: university),
      {'universityId': university},
    ),
    (
      'carrera con su universidad',
      const MaterialSearchQuery(universityId: university, careerId: career),
      {'universityId': university, 'careerId': career},
    ),
    (
      'asignatura con sus padres',
      const MaterialSearchQuery(
        universityId: university,
        careerId: career,
        subjectId: subject,
      ),
      {'universityId': university, 'careerId': career, 'subjectId': subject},
    ),
    (
      'docente con su jerarquía',
      const MaterialSearchQuery(
        universityId: university,
        careerId: career,
        subjectId: subject,
        professorId: professor,
      ),
      {
        'universityId': university,
        'careerId': career,
        'subjectId': subject,
        'professorId': professor,
      },
    ),
    for (final year in [1900, 2026, 2099])
      ('año $year', MaterialSearchQuery(year: year), {'year': year}),
    for (final type in ['DOCUMENT', 'PRESENTATION', 'EXAM', 'SUMMARY', 'LINK'])
      ('tipo $type', MaterialSearchQuery(type: type), {'type': type}),
  ];
  for (final (name, query, expected) in filters) {
    test('serializa $name sin añadir filtros ajenos', () async {
      final adapter = MaterialHttpAdapter(response(query: null), status: 200);
      await repository(adapter).search(query);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/v1/search');
      expect(adapter.requests.single.queryParameters, {
        ...expected,
        'page': 1,
        'pageSize': 10,
      });
    });
  }

  test(
    'combina texto, seis filtros y orden con IDs y valores normalizados',
    () async {
      final adapter = MaterialHttpAdapter(
        response(page: 2, pageSize: 20),
        status: 200,
      );
      await repository(adapter).search(
        const MaterialSearchQuery(
          text: ' álgebra ',
          universityId: ' $university ',
          careerId: ' $career ',
          subjectId: ' $subject ',
          professorId: ' $professor ',
          year: 2026,
          type: ' DOCUMENT ',
          sortBy: ' title ',
          order: ' asc ',
        ),
        page: 2,
        pageSize: 20,
      );
      expect(adapter.requests.single.queryParameters, {
        'q': 'álgebra',
        'universityId': university,
        'careerId': career,
        'subjectId': subject,
        'professorId': professor,
        'type': 'DOCUMENT',
        'sortBy': 'title',
        'order': 'asc',
        'year': 2026,
        'page': 2,
        'pageSize': 20,
      });
    },
  );

  for (final field in ['createdAt', 'title', 'year']) {
    for (final order in ['asc', 'desc']) {
      test('serializa orden público $field $order', () async {
        final adapter = MaterialHttpAdapter(response(query: null), status: 200);
        await repository(adapter)
            .search(MaterialSearchQuery(sortBy: field, order: order));
        expect(adapter.requests.single.queryParameters, {
          'sortBy': field,
          'order': order,
          'page': 1,
          'pageSize': 10,
        });
      });
    }
  }

  for (final pagination in [(1, 1), (2, 20), (3, 100)]) {
    test('conserva página y tamaño solicitados $pagination', () async {
      final adapter = MaterialHttpAdapter(
        response(page: pagination.$1, pageSize: pagination.$2),
        status: 200,
      );
      final result = await repository(adapter).search(
        const MaterialSearchQuery(text: 'álgebra'),
        page: pagination.$1,
        pageSize: pagination.$2,
      );
      expect(adapter.requests.single.queryParameters, {
        'q': 'álgebra',
        'page': pagination.$1,
        'pageSize': pagination.$2,
      });
      expect(result.page, pagination.$1);
      expect(result.pageSize, pagination.$2);
    });
  }

  for (final pagination in [
    (0, 10),
    (-1, 10),
    (1, 0),
    (1, 101),
    (2147483648, 10),
  ]) {
    test('paginación inválida $pagination no emite HTTP', () async {
      final adapter = MaterialHttpAdapter(response(), status: 200);
      await expectLater(
        repository(adapter).search(
          const MaterialSearchQuery(),
          page: pagination.$1,
          pageSize: pagination.$2,
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  }

  test('cancelación previa no consulta HTTP ni otro servicio', () async {
    final adapter = MaterialHttpAdapter(response(), status: 200);
    final token = CancelToken()..cancel('cancelado por usuario');
    await expectLater(
      repository(
        adapter,
      ).search(const MaterialSearchQuery(text: 'álgebra'), cancelToken: token),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'mensaje',
          contains('cancelada'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
}
