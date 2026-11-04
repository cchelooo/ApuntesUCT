import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
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
  final SearchRepository _searchRepo;
  final MaterialRepository _materialRepo;
  final CatalogSelectorRepository _catalogRepo;

  DioMaterialsDiscoveryRepository({
    required this._searchRepo,
    required this._materialRepo,
    required this._catalogRepo,
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
    final effectiveSubjectId =
        (subjectId != null && subjectId.trim().isNotEmpty)
            ? subjectId.trim()
            : ((cleanSubject != null && cleanSubject.isNotEmpty)
                ? cleanSubject
                : null);

    final cleanUniversityId =
        (universityId != null && universityId.trim().isNotEmpty)
            ? universityId.trim()
            : null;
    final cleanCareerId =
        (careerId != null && careerId.trim().isNotEmpty)
            ? careerId.trim()
            : null;
    final cleanProfessorId =
        (professorId != null && professorId.trim().isNotEmpty)
            ? professorId.trim()
            : null;
    final cleanType =
        (type != null && type.trim().isNotEmpty) ? type.trim() : null;

    final hasFilter =
        cleanQuery.isNotEmpty ||
        effectiveSubjectId != null ||
        cleanUniversityId != null ||
        cleanCareerId != null ||
        cleanProfessorId != null ||
        year != null ||
        cleanType != null;

    // 1. Si hay texto o algún filtro jerárquico/académico, consultar a Search Service vía Gateway
    if (hasFilter) {
      final pageResult = await _searchRepo.search(
        MaterialSearchQuery(
          text: cleanQuery,
          universityId: cleanUniversityId,
          careerId: cleanCareerId,
          subjectId: effectiveSubjectId,
          professorId: cleanProfessorId,
          year: year,
          type: cleanType,
        ),
        page: page,
        pageSize: pageSize,
      );
      return pageResult.items;
    }

    // 2. Listado general sin filtros: consultar a Material Service vía Gateway
    final pageResult = await _materialRepo.list(page: page, pageSize: pageSize);
    return pageResult.items;
  }

  @override
  Future<List<String>> getAvailableSubjects() async {
    return (await _catalogRepo.listSubjects())
        .map((subject) => subject.name)
        .toList();
  }

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async {
    try {
      return await _materialRepo.getDetail(id);
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
  final String? selectedUniversityName;
  final String? selectedCareerName;
  final String? selectedSubjectName;
  final String? selectedProfessorName;
  final String? errorMessage;
  final Object? error;

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
    this.selectedUniversityName,
    this.selectedCareerName,
    this.selectedSubjectName,
    this.selectedProfessorName,
    this.errorMessage,
    this.error,
  });

  bool get hasHierarchyFilters =>
      (selectedUniversityId != null && selectedUniversityId!.isNotEmpty) ||
      (selectedCareerId != null && selectedCareerId!.isNotEmpty) ||
      (selectedSubjectId != null && selectedSubjectId!.isNotEmpty) ||
      (selectedProfessorId != null && selectedProfessorId!.isNotEmpty) ||
      selectedYear != null ||
      (selectedType != null && selectedType!.isNotEmpty) ||
      (selectedSubject != null && selectedSubject!.isNotEmpty);

  bool get isSearchActive => query.trim().isNotEmpty || hasHierarchyFilters;

  int get activeFiltersCount {
    var count = 0;
    if (selectedUniversityId != null && selectedUniversityId!.isNotEmpty) {
      count++;
    }
    if (selectedCareerId != null && selectedCareerId!.isNotEmpty) count++;
    if ((selectedSubjectId != null && selectedSubjectId!.isNotEmpty) ||
        (selectedSubject != null && selectedSubject!.isNotEmpty)) {
      count++;
    }
    if (selectedProfessorId != null && selectedProfessorId!.isNotEmpty) {
      count++;
    }
    if (selectedYear != null) count++;
    if (selectedType != null && selectedType!.isNotEmpty) count++;
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
    bool clearUniversityId = false,
    String? selectedCareerId,
    bool clearCareerId = false,
    String? selectedSubjectId,
    bool clearSubjectId = false,
    String? selectedProfessorId,
    bool clearProfessorId = false,
    int? selectedYear,
    bool clearYear = false,
    String? selectedType,
    bool clearType = false,
    String? selectedUniversityName,
    bool clearUniversityName = false,
    String? selectedCareerName,
    bool clearCareerName = false,
    String? selectedSubjectName,
    bool clearSubjectName = false,
    String? selectedProfessorName,
    bool clearProfessorName = false,
    String? errorMessage,
    Object? error,
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
      selectedUniversityId: clearUniversityId
          ? null
          : (selectedUniversityId ?? this.selectedUniversityId),
      selectedCareerId: clearCareerId
          ? null
          : (selectedCareerId ?? this.selectedCareerId),
      selectedSubjectId: clearSubjectId
          ? null
          : (selectedSubjectId ?? this.selectedSubjectId),
      selectedProfessorId: clearProfessorId
          ? null
          : (selectedProfessorId ?? this.selectedProfessorId),
      selectedYear: clearYear ? null : (selectedYear ?? this.selectedYear),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      selectedUniversityName: clearUniversityName
          ? null
          : (selectedUniversityName ?? this.selectedUniversityName),
      selectedCareerName: clearCareerName
          ? null
          : (selectedCareerName ?? this.selectedCareerName),
      selectedSubjectName: clearSubjectName
          ? null
          : (selectedSubjectName ?? this.selectedSubjectName),
      selectedProfessorName: clearProfessorName
          ? null
          : (selectedProfessorName ?? this.selectedProfessorName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      error: clearError ? null : (error ?? this.error),
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
        error: error,
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
      selectedSubjectId: subject,
      selectedSubjectName: subject,
      clearSubject: subject == null,
      clearSubjectId: subject == null,
      clearSubjectName: subject == null,
      clearProfessorId: true,
      clearProfessorName: true,
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
    String? professorId,
    int? year,
    String? type,
    String? universityName,
    String? careerName,
    String? subjectName,
    String? professorName,
  }) async {
    state = state.copyWith(
      selectedUniversityId: universityId,
      clearUniversityId: universityId == null,
      selectedCareerId: careerId,
      clearCareerId: careerId == null,
      selectedSubjectId: subjectId,
      clearSubjectId: subjectId == null,
      selectedProfessorId: professorId,
      clearProfessorId: professorId == null,
      selectedYear: year,
      clearYear: year == null,
      selectedType: type,
      clearType: type == null,
      selectedUniversityName: universityName,
      clearUniversityName: universityName == null,
      selectedCareerName: careerName,
      clearCareerName: careerName == null,
      selectedSubjectName: subjectName,
      clearSubjectName: subjectName == null,
      selectedProfessorName: professorName,
      clearProfessorName: professorName == null,
      selectedSubject: subjectName ?? subjectId,
      clearSubject: subjectName == null && subjectId == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  /// Limpia niveles inferiores incompatibles al cambiar universidad y reinicia paginación a página 1.
  Future<void> setUniversity(
    String? universityId, {
    String? universityName,
  }) async {
    state = state.copyWith(
      selectedUniversityId: universityId,
      clearUniversityId: universityId == null,
      selectedUniversityName: universityName,
      clearUniversityName: universityName == null,
      clearCareerId: true,
      clearCareerName: true,
      clearSubjectId: true,
      clearSubjectName: true,
      clearSubject: true,
      clearProfessorId: true,
      clearProfessorName: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  /// Limpia niveles inferiores incompatibles al cambiar carrera y reinicia paginación a página 1.
  Future<void> setCareer(String? careerId, {String? careerName}) async {
    state = state.copyWith(
      selectedCareerId: careerId,
      clearCareerId: careerId == null,
      selectedCareerName: careerName,
      clearCareerName: careerName == null,
      clearSubjectId: true,
      clearSubjectName: true,
      clearSubject: true,
      clearProfessorId: true,
      clearProfessorName: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  /// Limpia niveles inferiores incompatibles al cambiar asignatura y reinicia paginación a página 1.
  Future<void> setSubjectHierarchy(
    String? subjectId, {
    String? subjectName,
  }) async {
    state = state.copyWith(
      selectedSubjectId: subjectId,
      clearSubjectId: subjectId == null,
      selectedSubjectName: subjectName,
      clearSubjectName: subjectName == null,
      selectedSubject: subjectName ?? subjectId,
      clearSubject: subjectName == null && subjectId == null,
      clearProfessorId: true,
      clearProfessorName: true,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setProfessor(
    String? professorId, {
    String? professorName,
  }) async {
    state = state.copyWith(
      selectedProfessorId: professorId,
      clearProfessorId: professorId == null,
      selectedProfessorName: professorName,
      clearProfessorName: professorName == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> setYear(int? year) async {
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
    state = state.copyWith(
      selectedType: type,
      clearType: type == null,
      isLoading: true,
      page: 1,
      clearError: true,
    );
    await _loadInitial();
  }

  Future<void> clearFilters() async {
    ref.read(academicHierarchyProvider.notifier).resetSelection();
    state = state.copyWith(
      query: '',
      clearSubject: true,
      clearUniversityId: true,
      clearCareerId: true,
      clearSubjectId: true,
      clearProfessorId: true,
      clearYear: true,
      clearType: true,
      clearUniversityName: true,
      clearCareerName: true,
      clearSubjectName: true,
      clearProfessorName: true,
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
        error: error,
      );
    }
  }
}

final discoveryMaterialsProvider =
    NotifierProvider<DiscoveryMaterialsNotifier, DiscoveryMaterialsState>(() {
      return DiscoveryMaterialsNotifier();
    });
