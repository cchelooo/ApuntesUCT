import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_gateway_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Opt-in: consume servicios reales. Nunca crea ni elimina datos del Backend.
void main() {
  const enabled = bool.fromEnvironment('RUN_GATEWAY_SMOKE');
  const unavailable = bool.fromEnvironment('GATEWAY_SERVICES_UNAVAILABLE');
  const expectedSubject = String.fromEnvironment('EXPECTED_SUBJECT_ID');
  const expectedMaterial = String.fromEnvironment('EXPECTED_MATERIAL_ID');
  late ProviderContainer container;

  setUp(
    () => container = ProviderContainer(retry: (retryCount, error) => null),
  );
  tearDown(() {
    container.read(apiclientProvider).dio.close(force: true);
    container.dispose();
  });

  test('Catalog real responde por el cliente Gateway de Mobile', () async {
    if (unavailable) {
      await expectLater(
        container.read(catalogRepositoryProvider).getCatalog(),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'statusCode', 502)
              .having((e) => e.error, 'error', isA<ApiException>()),
        ),
      );
    } else {
      final items = await container.read(catalogListProvider.future);
      if (expectedSubject.isNotEmpty) {
        expect(items.map((i) => i.id), contains(expectedSubject));
      }
    }
  }, skip: !enabled);

  test(
    'Material real responde por Gateway y conserva los errores 502',
    () async {
      if (unavailable) {
        await expectLater(
          container.read(materialListingRepositoryProvider).list(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having(
                  (e) => e.message,
                  'message',
                  'Material Service no disponible',
                ),
          ),
        );
      } else {
        final page = await container.read(materialListProvider(1).future);
        expect(page.page, 1);
        expect(page.pageSize, 10);
        expect(
          page.items.every((m) => m.reviewStatus == MaterialStatus.published),
          isTrue,
        );
        if (expectedMaterial.isNotEmpty) {
          expect(page.items.map((i) => i.id), contains(expectedMaterial));
        }
      }
    },
    skip: !enabled,
  );
}
