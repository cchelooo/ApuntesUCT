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
  group('CatalogRepository Tests (#66)', () {
    late Dio dio;
    late ApiClient apiClient;
    late CatalogRepository repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      dio.httpClientAdapter = MockDioAdapter((options) {
        if (options.queryParameters['search'] == 'Física') {
          return ResponseBody.fromString(
            '''[
              {"id": "3", "title": "Física I", "author": "Sears", "subject": "Física"}
            ]''',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        return ResponseBody.fromString(
          '''[
            {"id": "1", "title": "Cálculo I", "author": "Stewart", "subject": "Matemática"},
            {"id": "2", "title": "Álgebra Linear", "author": "Lay", "subject": "Álgebra"}
          ]''',
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
      'getCatalog retorna lista de CatalogItem en respuesta de éxito',
      () async {
        final result = await repository.getCatalog();

        expect(result.length, 2);
        expect(result.first.title, 'Cálculo I');
        expect(result.first.author, 'Stewart');
      },
    );

    test(
      'getCatalog envía query parameter cuando search es informado',
      () async {
        final result = await repository.getCatalog(search: 'Física');

        expect(result.length, 1);
        expect(result.first.subject, 'Física');
      },
    );
  });
}
