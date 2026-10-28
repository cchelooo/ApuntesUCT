import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/mock_materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Implementación real conectada al Gateway (Search Service y Material Service)
/// con fallback a MockMaterialsRepository en entornos desconectados o pruebas de UI.
class DioMaterialsDiscoveryRepository implements MaterialsRepository {
  final DioSearchRepository _searchRepo;
  final DioMaterialRepository _materialRepo;
  final MockMaterialsRepository _fallbackMock = MockMaterialsRepository();

  DioMaterialsDiscoveryRepository({
    required this._searchRepo,
    required this._materialRepo,
  });

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  }) async {
    final cleanQuery = query?.trim() ?? '';
    final cleanSubject = subject?.trim();

    // 1. Si hay texto o filtro de asignatura, consultar a Search Service vía Gateway
    if (cleanQuery.isNotEmpty ||
        (cleanSubject != null && cleanSubject.isNotEmpty)) {
      try {
        final pageResult = await _searchRepo.search(
          MaterialSearchQuery(text: cleanQuery, subjectId: cleanSubject),
          page: page,
          pageSize: pageSize,
        );
        return pageResult.items;
      } catch (_) {
        // Fallback para entornos sin conexión o pruebas locales
        return _fallbackMock.getMaterials(
          query: cleanQuery,
          subject: cleanSubject,
          page: page,
          pageSize: pageSize,
        );
      }
    }

    // 2. Listado general sin filtros: consultar a Material Service vía Gateway
    try {
      final pageResult = await _materialRepo.list(
        page: page,
        pageSize: pageSize,
      );
      return pageResult.items;
    } catch (_) {
      // Fallback para entornos sin conexión o pruebas locales
      return _fallbackMock.getMaterials(
        query: cleanQuery,
        subject: cleanSubject,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  @override
  Future<List<String>> getAvailableSubjects() async {
    return _fallbackMock.getAvailableSubjects();
  }

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async {
    try {
      return await _materialRepo.getDetail(id);
    } catch (_) {
      return _fallbackMock.getMaterialDetail(id);
    }
  }
}

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioMaterialsDiscoveryRepository(
    searchRepo: DioSearchRepository(apiClient),
    materialRepo: DioMaterialRepository(apiClient),
  );
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
    bool clearError = false,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
    state = state.copyWith(isLoadingMore: false, clearError: true);
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

      if (requestId != _activeRequestId) return;

      // Deduplicación preventiva en carga inicial
      final seenIds = <String>{};
      final uniqueResults = results
          .where((item) => seenIds.add(item.id))
          .toList();

      state = state.copyWith(
        items: uniqueResults,
        isLoading: false,
        page: 1,
        hasMore: results.length >= pageSize,
        clearError: true,
      );
    } catch (_) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Error al cargar materiales disponibles. Verifica tu conexión.',
      );
    }
  }

  Future<void> setQuery(String newQuery) async {
    final clean = newQuery.trim();
    if (state.query == clean) return;
    state = state.copyWith(
      query: clean,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setSubject(String? subject) async {
    state = state.copyWith(
      selectedSubject: subject,
      clearSubject: subject == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      query: '',
      clearSubject: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, page: 1, clearError: true);
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

      if (requestId != _activeRequestId) return;

      // Fix de Codex: deduplicar elemento a elemento actualizando el conjunto
      // de IDs para no admitir repetidos dentro de la página nueva
      final seenIds = state.items.map((m) => m.id).toSet();
      final uniqueNewItems = <MaterialSummary>[];
      for (final item in nextItems) {
        if (seenIds.add(item.id)) {
          uniqueNewItems.add(item);
        }
      }

      state = state.copyWith(
        items: [...state.items, ...uniqueNewItems],
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
