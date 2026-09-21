import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDioAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CatalogRepository Tests (#66 - Estructura Árbol)', () {
    late Dio dio;
    late ApiClient apiClient;
    late CatalogRepository repository;

    final treeMockJson = '''[
      {
        "id": "uni-1",
        "name": "Universidad Católica de Temuco",
        "careers": [
          {
            "id": "car-1",
            "name": "Ingeniería Civil Informática",
            "subjects": [
              {
                "id": "sub-1",
                "name": "Estructuras de Datos",
                "description": "Algoritmos y estructuras"
              },
              {
                "id": "sub-2",
                "name": "Cálculo I",
                "description": "Límites y derivadas"
              }
            ]
          }
        ]
      }
    ]''';

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:3002/api/v1'));
      dio.httpClientAdapter = MockDioAdapter((options) {
        return ResponseBody.fromString(
          treeMockJson,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      apiClient = ApiClient(customDio: dio);
      repository = CatalogRepository(apiClient);
    });

    test(
      'getCatalog aplana el árbol y retorna las asignaturas como CatalogItem',
      () async {
        final result = await repository.getCatalog();

        expect(result.length, 2);
        expect(result.first.title, 'Estructuras de Datos');
        expect(result.first.subject, 'Ingeniería Civil Informática');
        expect(result.first.author, 'Universidad Católica de Temuco');
      },
    );

    test(
      'getCatalog filtra en memoria correctamente cuando search está presente',
      () async {
        final result = await repository.getCatalog(search: 'Cálculo');

        expect(result.length, 1);
        expect(result.first.title, 'Cálculo I');
      },
    );
  });
}
