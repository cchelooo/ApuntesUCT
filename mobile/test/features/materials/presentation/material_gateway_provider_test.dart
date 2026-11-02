import 'dart:async';

import 'package:apuntesuct_mobile/core/config/api_config.dart';
import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_listing_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_gateway_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMaterialListingRepository implements MaterialListingRepository {
  FakeMaterialListingRepository(this.result);
  final Future<MaterialPage> result;
  int? requestedPage;

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) {
    requestedPage = page;
    return result;
  }
}

void main() {
  test(
    'Material y Catalog comparten el cliente central y sus interceptores',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = container.read(apiclientProvider);
      addTearDown(() => client.dio.close(force: true));
      expect(container.read(materialApiClientProvider), same(client));
      expect(container.read(catalogApiClientProvider), same(client));
      expect(client.dio.options.baseUrl, ApiConfig.gatewayBaseUrl);
    },
  );

  test('un override central reemplaza el transporte de ambos dominios', () {
    final client = ApiClient(baseUrl: 'https://gateway.example.test/api/v1');
    addTearDown(() => client.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [apiclientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    expect(container.read(materialApiClientProvider), same(client));
    expect(container.read(catalogApiClientProvider), same(client));
  });

  test('el fake de Material expone loading y data sin construir Dio', () async {
    final result = Completer<MaterialPage>();
    final fake = FakeMaterialListingRepository(result.future);
    final container = ProviderContainer(
      overrides: [
        apiclientProvider.overrideWith(
          (ref) => throw StateError('No debe construir HTTP'),
        ),
        materialListingRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(materialListProvider(3), (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(materialListProvider(3)).isLoading, isTrue);
    final page = MaterialPage(items: [], page: 3, pageSize: 10, total: 0);
    result.complete(page);
    expect(await container.read(materialListProvider(3).future), same(page));
    expect(fake.requestedPage, 3);
    expect(container.read(materialListProvider(3)).requireValue, same(page));
  });

  test(
    'el provider expone AsyncError con el error original del repositorio',
    () async {
      final result = Completer<MaterialPage>();
      final error = ApiException(
        message: 'Material Service no disponible',
        statusCode: 502,
      );
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          materialListingRepositoryProvider.overrideWithValue(
            FakeMaterialListingRepository(result.future),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(materialListProvider(1), (_, _) {});
      addTearDown(subscription.close);
      final future = container.read(materialListProvider(1).future);
      final assertion = expectLater(future, throwsA(same(error)));
      result.completeError(error);
      await assertion;
      expect(container.read(materialListProvider(1)).error, same(error));
    },
  );
}
