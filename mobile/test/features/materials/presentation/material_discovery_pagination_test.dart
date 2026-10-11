import 'dart:async';

import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledDiscoveryRepository implements MaterialsRepository {
  final requests = <Completer<List<MaterialSummary>>>[];

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  }) {
    final request = Completer<List<MaterialSummary>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<String>> getAvailableSubjects() async => ['Cálculo'];

  @override
  Future<MaterialDetail> getMaterialDetail(String id) =>
      throw UnimplementedError();
}

List<MaterialSummary> items(String prefix) => List.generate(
  5,
  (i) => MaterialSummary(id: '$prefix-$i', title: '$prefix-$i'),
);

void main() {
  for (final action in ['búsqueda', 'filtro', 'refresco']) {
    for (final oldFails in [false, true]) {
      test(
        '$action reinicia paginación aunque la página antigua ${oldFails ? 'falle' : 'responda'}',
        () async {
          final repository = ControlledDiscoveryRepository();
          final container = ProviderContainer(
            overrides: [
              materialsRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(discoveryMaterialsProvider.notifier);
          repository.requests[0].complete(items('inicial'));
          await Future<void>.delayed(Duration.zero);

          final oldPage = notifier.loadNextPage();
          expect(
            container.read(discoveryMaterialsProvider).isLoadingMore,
            isTrue,
          );
          final reload = switch (action) {
            'búsqueda' => notifier.setQuery('nueva'),
            'filtro' => notifier.setSubject('Cálculo'),
            _ => notifier.refresh(),
          };
          repository.requests[2].complete(items('nueva'));
          await reload;
          expect(
            container.read(discoveryMaterialsProvider).isLoadingMore,
            isFalse,
          );
          expect(container.read(discoveryMaterialsProvider).page, 1);

          // La nueva búsqueda puede paginar antes de que termine la página descartada.
          final newPage = notifier.loadNextPage();
          expect(repository.requests, hasLength(4));
          if (oldFails) {
            repository.requests[1].completeError(
              Exception('Página antigua fallida'),
            );
          } else {
            repository.requests[1].complete(items('vieja'));
          }
          await oldPage;
          expect(
            container.read(discoveryMaterialsProvider).isLoadingMore,
            isTrue,
          );
          expect(
            container.read(discoveryMaterialsProvider).items.first.id,
            'nueva-0',
          );
          expect(
            container.read(discoveryMaterialsProvider).errorMessage,
            isNull,
          );
          repository.requests[3].complete([
            const MaterialSummary(id: 'nueva-5', title: 'Siguiente'),
          ]);
          await newPage;
          final state = container.read(discoveryMaterialsProvider);
          expect(state.items.map((m) => m.id), [
            ...items('nueva').map((m) => m.id),
            'nueva-5',
          ]);
          expect(state.page, 2);
          expect(state.hasMore, isFalse);
          expect(state.isLoadingMore, isFalse);
        },
      );
    }
  }
}
