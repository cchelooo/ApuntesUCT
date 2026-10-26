import 'dart:async';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Páginas del dominio interno: no pretenden definir un JSON de Search de INT2.
MaterialPage page(String id, {int number = 1, int total = 30}) => MaterialPage(
  items: [MaterialSummary(id: id, title: id)],
  page: number,
  pageSize: 10,
  total: total,
);

class PendingSearch implements SearchRepository {
  final requests = <(MaterialSearchQuery, int, int)>[];
  final responses = <Completer<MaterialPage>>[];
  @override
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
  }) {
    requests.add((query, page, pageSize));
    final response = Completer<MaterialPage>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  late PendingSearch repository;
  late ProviderContainer container;
  late MaterialSearchController controller;
  setUp(() {
    repository = PendingSearch();
    container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(repository)],
    );
    controller = container.read(materialSearchControllerProvider.notifier);
  });
  tearDown(() => container.dispose());
  MaterialSearchState state() =>
      container.read(materialSearchControllerProvider);

  test('una búsqueda nueva descarta la respuesta anterior', () async {
    final old = controller.search(const MaterialSearchQuery(text: 'vieja'));
    final latest = controller.search(const MaterialSearchQuery(text: 'nueva'));
    repository.responses[1].complete(page('nuevo'));
    await latest;
    repository.responses[0].complete(page('obsoleto'));
    await old;
    expect(state().query.text, 'nueva');
    expect(state().items.single.id, 'nuevo');
    expect(state().isLoadingMore, isFalse);
  });

  test(
    'página antigua no bloquea la paginación de una nueva consulta',
    () async {
      final first = controller.search(const MaterialSearchQuery(text: 'vieja'));
      repository.responses[0].complete(page('v1'));
      await first;
      final oldPage = controller.loadMore();
      expect(state().isLoadingMore, isTrue);
      final latest = controller.search(
        const MaterialSearchQuery(text: 'nueva'),
      );
      expect(state().isLoadingMore, isFalse);
      expect(state().items, isEmpty);
      repository.responses[2].complete(page('n1'));
      await latest;
      final newPage = controller.loadMore();
      repository.responses[1].complete(page('v2', number: 2));
      await oldPage;
      expect(state().isLoadingMore, isTrue);
      expect(state().items.single.id, 'n1');
      repository.responses[3].complete(page('n2', number: 2));
      await newPage;
      expect(state().items.map((item) => item.id), ['n1', 'n2']);
      expect(state().isLoadingMore, isFalse);
      expect(repository.requests[3].$1.text, 'nueva');
      expect(repository.requests[3].$2, 2);
    },
  );

  test(
    'no duplica peticiones concurrentes ni elementos en la página nueva',
    () async {
      final first = controller.search(const MaterialSearchQuery());
      repository.responses[0].complete(page('1'));
      await first;
      final more = controller.loadMore();
      await controller.loadMore();
      expect(repository.requests, hasLength(2));
      repository.responses[1].complete(
        MaterialPage(
          items: const [
            MaterialSummary(id: '1', title: 'duplicado'),
            MaterialSummary(id: '2', title: 'nuevo'),
            MaterialSummary(id: '2', title: 'duplicado interno'),
          ],
          page: 2,
          pageSize: 10,
          total: 3,
        ),
      );
      await more;
      expect(state().items.map((item) => item.id), ['1', '2']);
      await controller.loadMore();
      expect(repository.requests, hasLength(2));
    },
  );

  test('fallo de página conserva resultados y permite reintentar', () async {
    final first = controller.search(const MaterialSearchQuery(text: 'actual'));
    repository.responses[0].complete(page('1'));
    await first;
    final more = controller.loadMore();
    final error = ApiException(
      message: 'Servicio no disponible',
      statusCode: 502,
    );
    repository.responses[1].completeError(error);
    await more;
    expect(state().pageError, same(error));
    expect(state().items.single.id, '1');
    expect(state().isLoadingMore, isFalse);
    final retry = controller.loadMore();
    expect(state().pageError, isNull);
    repository.responses[2].complete(page('2', number: 2));
    await retry;
    expect(state().items.map((item) => item.id), ['1', '2']);
  });

  test('error de búsqueda es visible y no usa un mock de respaldo', () async {
    final first = controller.search(const MaterialSearchQuery());
    final error = ApiException(message: 'Integración pendiente');
    repository.responses[0].completeError(error);
    await first;
    expect(state().result!.asError!.error, same(error));
    expect(state().items, isEmpty);
    await controller.loadMore();
    expect(repository.requests, hasLength(1));
  });

  test(
    'descartar el provider ignora respuestas que sigan pendientes',
    () async {
      final first = controller.search(const MaterialSearchQuery());
      container.invalidate(materialSearchControllerProvider);
      repository.responses[0].complete(page('obsoleto'));
      await first;
      expect(state().result, isNull);
    },
  );
}
