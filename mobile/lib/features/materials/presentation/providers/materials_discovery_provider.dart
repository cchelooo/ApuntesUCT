import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Consumo de Discovery mediante Gateway. Los mocks requieren un override
/// explícito y nunca se usan para recuperar silenciosamente errores HTTP.
class DioMaterialsDiscoveryRepository implements MaterialsRepository {
  final SearchRepository searchRepo;
  final MaterialRepository materialRepo;
  final CatalogSelectorRepository catalogRepo;

  DioMaterialsDiscoveryRepository({
    required this.searchRepo,
    required this.materialRepo,
    required this.catalogRepo,
  });

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    String? universityId,
    String? careerId,
    String? subjectId,
    String? professorId,
    int? year,
    String? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    final cleanQuery = query?.trim() ?? '';
    final cleanSubject = subject?.trim();
    final cleanType = type?.trim();

    final hasFilters = cleanQuery.isNotEmpty ||
        (cleanSubject != null && cleanSubject.isNotEmpty) ||
        (universityId != null && universityId.trim().isNotEmpty) ||
        (careerId != null && careerId.trim().isNotEmpty) ||
        (subjectId != null && subjectId.trim().isNotEmpty) ||
        (professorId != null && professorId.trim().isNotEmpty) ||
        year != null ||
        (cleanType != null && cleanType.isNotEmpty);

    // 1. Si hay texto o cualquier filtro (incluidos año y tipo), consultar a Search Service vía Gateway
    if (hasFilters) {
      final pageResult = await searchRepo.search(
        MaterialSearchQuery(
          text: cleanQuery,
          universityId: universityId?.trim(),
          careerId: careerId?.trim(),
          subjectId: subjectId?.trim().isNotEmpty == true
              ? subjectId?.trim()
              : cleanSubject,
          professorId: professorId?.trim(),
          year: year,
          type: cleanType,
        ),
        page: page,
        pageSize: pageSize,
      );
      return pageResult.items;
    }

    // 2. Listado general sin filtros: consultar a Material Service vía Gateway
    final pageResult = await materialRepo.list(page: page, pageSize: pageSize);
    return pageResult.items;
  }

  @override
  Future<List<String>> getAvailableSubjects() async {
    return (await catalogRepo.listSubjects())
        .map((subject) => subject.name)
        .toList();
  }

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async {
    try {
      return await materialRepo.getDetail(id);
    } on ApiException catch (error) {
      if (error.statusCode == 404) throw MaterialNotFoundException(id);
      rethrow;
    }
  }
}

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioMaterialsDiscoveryRepository(
    searchRepo: DioSearchRepository(apiClient),
    materialRepo: DioMaterialRepository(apiClient),
    catalogRepo: CatalogSelectorRepository(apiClient),
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
  final String? selectedUniversityId;
  final String? selectedCareerId;
  final String? selectedSubjectId;
  final String? selectedProfessorId;
  final int? selectedYear;
  final String? selectedType;
  final String? errorMessage;

  const DiscoveryMaterialsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.query = '',
    this.selectedSubject,
    this.selectedUniversityId,
    this.selectedCareerId,
    this.selectedSubjectId,
    this.selectedProfessorId,
    this.selectedYear,
    this.selectedType,
    this.errorMessage,
  });

  bool get hasHierarchyFilters =>
      selectedUniversityId != null ||
      selectedCareerId != null ||
      selectedSubjectId != null ||
      selectedProfessorId != null ||
      selectedYear != null ||
      selectedType != null ||
      selectedSubject != null;

  bool get isSearchActive => query.trim().isNotEmpty || hasHierarchyFilters;

  int get activeFiltersCount {
    var count = 0;
    if (selectedUniversityId != null) count++;
    if (selectedCareerId != null) count++;
    if (selectedSubjectId != null || selectedSubject != null) count++;
    if (selectedProfessorId != null) count++;
    if (selectedYear != null) count++;
    if (selectedType != null) count++;
    return count;
  }

  DiscoveryMaterialsState copyWith({
    List<MaterialSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? query,
    String? selectedSubject,
    bool clearSubject = false,
    String? selectedUniversityId,
    bool clearUniversity = false,
    String? selectedCareerId,
    bool clearCareer = false,
    String? selectedSubjectId,
    bool clearSubjectId = false,
    String? selectedProfessorId,
    bool clearProfessor = false,
    int? selectedYear,
    bool clearYear = false,
    String? selectedType,
    bool clearType = false,
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
      selectedUniversityId: clearUniversity
          ? null
          : (selectedUniversityId ?? this.selectedUniversityId),
      selectedCareerId: clearCareer
          ? null
          : (selectedCareerId ?? this.selectedCareerId),
      selectedSubjectId: clearSubjectId
          ? null
          : (selectedSubjectId ?? this.selectedSubjectId),
      selectedProfessorId: clearProfessor
          ? null
          : (selectedProfessorId ?? this.selectedProfessorId),
      selectedYear: clearYear ? null : (selectedYear ?? this.selectedYear),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
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

    try {
      final results = await repo.getMaterials(
        query: state.query,
        subject: state.selectedSubject,
        universityId: state.selectedUniversityId,
        careerId: state.selectedCareerId,
        subjectId: state.selectedSubjectId,
        professorId: state.selectedProfessorId,
        year: state.selectedYear,
        type: state.selectedType,
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
    } catch (error) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: apiErrorMessage(
          error,
          fallback:
              'Error al cargar materiales disponibles. Verifica tu conexión.',
        ),
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

  Future<void> setYear(int? year) async {
    if (state.selectedYear == year) return;
    state = state.copyWith(
      selectedYear: year,
      clearYear: year == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setType(String? type) async {
    final clean = type?.trim();
    if (state.selectedType == clean) return;
    state = state.copyWith(
      selectedType: clean,
      clearType: clean == null || clean.isEmpty,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> clearYear() async {
    ref.read(academicHierarchyProvider.notifier).selectYear(null);
    state = state.copyWith(
      clearYear: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> clearType() async {
    ref.read(academicHierarchyProvider.notifier).selectType(null);
    state = state.copyWith(
      clearType: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setUniversity(String? universityId) async {
    if (state.selectedUniversityId == universityId) return;
    state = state.copyWith(
      selectedUniversityId: universityId,
      clearUniversity: universityId == null,
      clearCareer: true,
      clearSubjectId: true,
      clearSubject: true,
      clearProfessor: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setCareer(String? careerId) async {
    if (state.selectedCareerId == careerId) return;
    state = state.copyWith(
      selectedCareerId: careerId,
      clearCareer: careerId == null,
      clearSubjectId: true,
      clearSubject: true,
      clearProfessor: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setSubjectHierarchy(String? subjectId, [String? subjectName]) async {
    if (state.selectedSubjectId == subjectId && state.selectedSubject == subjectName) return;
    state = state.copyWith(
      selectedSubjectId: subjectId,
      clearSubjectId: subjectId == null,
      selectedSubject: subjectName,
      clearSubject: subjectName == null,
      clearProfessor: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setProfessor(String? professorId) async {
    if (state.selectedProfessorId == professorId) return;
    state = state.copyWith(
      selectedProfessorId: professorId,
      clearProfessor: professorId == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> applyHierarchyFilters({
    String? universityId,
    String? careerId,
    String? subjectId,
    String? subjectName,
    String? professorId,
    int? year,
    String? type,
  }) async {
    state = state.copyWith(
      selectedUniversityId: universityId,
      clearUniversity: universityId == null,
      selectedCareerId: careerId,
      clearCareer: careerId == null,
      selectedSubjectId: subjectId,
      clearSubjectId: subjectId == null,
      selectedSubject: subjectName,
      clearSubject: subjectName == null,
      selectedProfessorId: professorId,
      clearProfessor: professorId == null,
      selectedYear: year,
      clearYear: year == null,
      selectedType: type,
      clearType: type == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  /// Limpia todos los filtros activos, restablece consulta y reinicia paginación a la página 1 (Issue #295).
  Future<void> clearFilters() async {
    // Restablece la jerarquía académica si está activa
    ref.read(academicHierarchyProvider.notifier).resetSelection();

    state = const DiscoveryMaterialsState(isLoading: true, page: 1);
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

    try {
      final nextItems = await repo.getMaterials(
        query: state.query,
        subject: state.selectedSubject,
        universityId: state.selectedUniversityId,
        careerId: state.selectedCareerId,
        subjectId: state.selectedSubjectId,
        professorId: state.selectedProfessorId,
        year: state.selectedYear,
        type: state.selectedType,
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
    } catch (error) {
      if (requestId != _activeRequestId) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: apiErrorMessage(
          error,
          fallback: 'No fue posible cargar más materiales.',
        ),
      );
    }
  }
}

final discoveryMaterialsProvider =
    NotifierProvider<DiscoveryMaterialsNotifier, DiscoveryMaterialsState>(() {
      return DiscoveryMaterialsNotifier();
    });
