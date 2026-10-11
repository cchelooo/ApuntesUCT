import 'package:apuntesuct_mobile/core/config/api_config.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_catalog_repository.dart';

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '[{"id":"uni-1","name":"UCT","careers":[{"id":"car-1","name":"Informática","subjects":[{"id":"sub-1","name":"Cálculo"}]}]}]',
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
  test('Catalog utiliza el cliente central del Gateway por defecto', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(catalogApiClientProvider);
    expect(client, same(container.read(apiclientProvider)));
    expect(client.dio.options.baseUrl, ApiConfig.gatewayBaseUrl);
    addTearDown(() => client.dio.close(force: true));
  });

  test('un override central envía GET al Gateway y conserva el parseo del catálogo', () async {
    final adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(customDio: dio);
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [apiclientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final items = await container.read(catalogListProvider.future);
    expect(adapter.request?.method, 'GET');
    expect(
      adapter.request?.uri.toString(),
      'https://gateway.example.test/api/v1/catalog',
    );
    expect(items.single.id, 'sub-1');
    expect(items.single.title, 'Cálculo');
    expect(container.read(catalogApiClientProvider), same(client));
  });

  test('un fake sustituye Catalog sin construir el cliente HTTP', () async {
    final container = ProviderContainer(
      overrides: [
        apiclientProvider.overrideWith(
          (ref) => throw StateError('No debe consultar HTTP'),
        ),
        catalogRepositoryProvider.overrideWithValue(
          const FakeCatalogRepository(
            items: [
              CatalogItem(
                id: 'sub-fixture',
                title: 'Fixture',
                author: 'UCT',
                subject: 'Informática',
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final items = await container.read(catalogListProvider.future);
    expect(items.single.id, 'sub-fixture');
  });
}
