import 'package:apuntesuct_mobile/features/materials/data/mock_materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  return MockMaterialsRepository();
});

final availableSubjectsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final repository = ref.watch(materialsRepositoryProvider);
  return repository.getAvailableSubjects();
});

class DiscoveryMaterialsState {
  final List<MaterialSummary> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String query;
  final String? selectedSubject;
  final String? errorMessage;

  const DiscoveryMaterialsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.query = '',
    this.selectedSubject,
    this.errorMessage,
  });

  bool get isSearchActive => query.trim().isNotEmpty || selectedSubject != null;

  DiscoveryMaterialsState copyWith({
    List<MaterialSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? query,
    String? selectedSubject,
    bool clearSubject = false,
    String? errorMessage,
  }) {
    return DiscoveryMaterialsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      query: query ?? this.query,
      selectedSubject: clearSubject
          ? null
          : (selectedSubject ?? this.selectedSubject),
      errorMessage: errorMessage,
    );
  }
}

class DiscoveryMaterialsNotifier extends Notifier<DiscoveryMaterialsState> {
  static const int pageSize = 5;
  int _activeRequestId = 0;

  @override
  DiscoveryMaterialsState build() {
    state = const DiscoveryMaterialsState(isLoading: true);
    _loadInitial();
    return state;
  }

  Future<void> _loadInitial() async {
    final requestId = ++_activeRequestId;
    // La nueva consulta ya no espera la página anterior que será descartada.
    state = state.copyWith(isLoadingMore: false);
    final repo = ref.read(materialsRepositoryProvider);
    final targetQuery = state.query;
    final targetSubject = state.selectedSubject;

    try {
      final results = await repo.getMaterials(
        query: targetQuery,
        subject: targetSubject,
        page: 1,
        pageSize: pageSize,
      );

      // Si se disparó otra búsqueda o filtro mientras esperaba, ignorar respuesta vieja
      if (requestId != _activeRequestId) return;

      state = state.copyWith(
        items: results,
        isLoading: false,
        page: 1,
        hasMore: results.length >= pageSize,
        errorMessage: null,
      );
    } catch (e) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar materiales disponibles.',
      );
    }
  }

  Future<void> setQuery(String newQuery) async {
    final clean = newQuery.trim();
    if (state.query == clean) return;
    state = state.copyWith(query: clean, isLoading: true, page: 1);
    await _loadInitial();
  }

  Future<void> setSubject(String? subject) async {
    state = state.copyWith(
      selectedSubject: subject,
      clearSubject: subject == null,
      isLoading: true,
      page: 1,
    );
    await _loadInitial();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, page: 1);
    await _loadInitial();
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final requestId = _activeRequestId;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;
    final repo = ref.read(materialsRepositoryProvider);
    final targetQuery = state.query;
    final targetSubject = state.selectedSubject;

    try {
      final nextItems = await repo.getMaterials(
        query: targetQuery,
        subject: targetSubject,
        page: nextPage,
        pageSize: pageSize,
      );

      // Si la búsqueda cambió mientras cargaba la siguiente página, descartar
      if (requestId != _activeRequestId) return;

      state = state.copyWith(
        items: [...state.items, ...nextItems],
        page: nextPage,
        hasMore: nextItems.length >= pageSize,
        isLoadingMore: false,
      );
    } catch (_) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final discoveryMaterialsProvider =
    NotifierProvider<DiscoveryMaterialsNotifier, DiscoveryMaterialsState>(() {
      return DiscoveryMaterialsNotifier();
    });
