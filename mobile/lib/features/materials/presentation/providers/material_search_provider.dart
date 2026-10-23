import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/dio_search_repository.dart';
import '../../domain/models/material_page.dart';
import '../../domain/models/material_requests.dart';
import '../../domain/models/material_summary.dart';
import '../../domain/repositories/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return DioSearchRepository(ref.watch(apiclientProvider));
});

class MaterialSearchState {
  final MaterialSearchQuery query;
  final AsyncValue<MaterialPage>? result;
  final bool isLoadingMore;
  final Object? pageError;
  final List<MaterialSummary> items;

  const MaterialSearchState({
    this.query = const MaterialSearchQuery(),
    this.result,
    this.isLoadingMore = false,
    this.pageError,
    this.items = const [],
  });
}

/// Preparado para una futura respuesta paginada del dominio. No conecta ni
/// reemplaza el mock de Descubrir Materiales mientras Search sea un stub.
class MaterialSearchController extends Notifier<MaterialSearchState> {
  int _generation = 0;

  @override
  MaterialSearchState build() {
    ref.onDispose(() => _generation++);
    return const MaterialSearchState();
  }

  Future<void> search(MaterialSearchQuery query) async {
    final generation = ++_generation;
    final repository = ref.read(searchRepositoryProvider);
    state = MaterialSearchState(query: query, result: const AsyncLoading());
    final result = await AsyncValue.guard(() => repository.search(query));
    if (generation != _generation) return;
    state = MaterialSearchState(
      query: query,
      result: result,
      items: result.asData?.value.items ?? const [],
    );
  }

  Future<void> loadMore() async {
    final current = state.result?.asData?.value;
    if (current == null || !current.hasNextPage || state.isLoadingMore) return;
    final generation = _generation;
    final previousItems = state.items;
    final query = state.query;
    final repository = ref.read(searchRepositoryProvider);
    state = MaterialSearchState(
      query: query,
      result: state.result,
      isLoadingMore: true,
      items: previousItems,
    );
    try {
      final next = await repository.search(
        query,
        page: current.page + 1,
        pageSize: current.pageSize,
      );
      if (generation != _generation) return;
      if (next.page != current.page + 1 || next.pageSize != current.pageSize) {
        throw const FormatException(
          'La página recibida no corresponde a la solicitud.',
        );
      }
      final seen = previousItems.map((item) => item.id).toSet();
      final items = List<MaterialSummary>.unmodifiable([
        ...previousItems,
        ...next.items.where((item) => seen.add(item.id)),
      ]);
      state = MaterialSearchState(
        query: query,
        result: AsyncData(next),
        items: items,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = MaterialSearchState(
        query: query,
        result: AsyncData(current),
        pageError: error,
        items: previousItems,
      );
    }
  }
}

final materialSearchControllerProvider =
    NotifierProvider<MaterialSearchController, MaterialSearchState>(
      MaterialSearchController.new,
    );
