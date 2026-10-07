import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_listing_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MaterialResponseAdapter implements HttpClientAdapter {
  MaterialResponseAdapter(this.data, {this.statusCode = 200});
  final Object? data;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  DioMaterialListingRepository repository(MaterialResponseAdapter adapter) {
    dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioMaterialListingRepository(ApiClient(customDio: dio));
  }

  test(
    'consulta el listado paginado por Gateway e interpreta PUBLISHED',
    () async {
      final payload = jsonDecode(
        File('test/fixtures/materials/gateway_list.json').readAsStringSync(),
      );
      final adapter = MaterialResponseAdapter(payload);
      final page = await repository(adapter).list(page: 2, pageSize: 2);
      expect(adapter.request!.uri.origin, 'https://gateway.example.test');
      expect(adapter.request!.uri.path, '/api/v1/materials');
      expect(adapter.request!.uri.queryParameters, {
        'page': '2',
        'pageSize': '2',
      });
      expect(page.page, 2);
      expect(page.pageSize, 2);
      expect(page.total, 3);
      expect(page.items.single.reviewStatus, MaterialStatus.published);
      expect(page.items.single.reviewStatus.label, 'Publicado');
      expect(page.items.single.subject?.id, 'subject-test');
      expect(page.items.single.subject?.name, isNull);
      expect(page.items.single.createdAt, DateTime.utc(2026, 10, 7, 12));
      expect(page.hasNextPage, isFalse);
    },
  );

  test(
    'una página posterior al final conserva el total y devuelve items vacíos',
    () async {
      final page = await repository(
        MaterialResponseAdapter({
          'items': [],
          'page': 9,
          'pageSize': 10,
          'total': 3,
        }),
      ).list(page: 9);
      expect(page.items, isEmpty);
      expect(page.page, 9);
      expect(page.total, 3);
      expect(page.hasNextPage, isFalse);
    },
  );

  for (final code in [400, 502]) {
    test('conserva el código y mensaje HTTP $code del Gateway', () async {
      final repo = repository(
        MaterialResponseAdapter({
          'statusCode': code,
          'message': 'Material Service no disponible',
        }, statusCode: code),
      );
      await expectLater(
        repo.list(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', code)
              .having(
                (e) => e.message,
                'message',
                'Material Service no disponible',
              ),
        ),
      );
    });
  }

  test(
    'la respuesta inválida se expone como error, no como listado vacío',
    () async {
      for (final payload in <Object?>[
        null,
        [],
        {'items': [], 'page': 1},
        {
          'items': [
            {'id': '', 'title': 'Inválido'},
          ],
          'page': 1,
          'pageSize': 10,
          'total': 1,
        },
      ]) {
        await expectLater(
          repository(MaterialResponseAdapter(payload)).list(),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test('rechaza paginación fuera del contrato antes de enviar HTTP', () async {
    final adapter = MaterialResponseAdapter(null);
    final repo = repository(adapter);
    for (final args in [(0, 10), (1, 0), (1, 101), (2147483647, 100)]) {
      await expectLater(
        repo.list(page: args.$1, pageSize: args.$2),
        throwsArgumentError,
      );
    }
    expect(adapter.request, isNull);
  });
}
