import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';

/// Provider de repositorio que puede ser sobreescrito en tests
/// mediante [ProviderContainer.overrides].
final academicHierarchyRepositoryProvider =
    Provider<IAcademicHierarchyRepository>(
      (_) => MockAcademicHierarchyRepository(),
    );

// ---------------------------------------------------------------------------
// AcademicHierarchySelection — 6 niveles (Issue #281, #282 y #289)
// ---------------------------------------------------------------------------

/// Representa la selección académica actual en la jerarquía oficial de 6 niveles:
/// 1. Universidad
/// 2. Carrera
/// 3. Asignatura
/// 4. Profesor
/// 5. Año académico
/// 6. Tipo de material
///
/// Los niveles Año y Tipo son independientes de la cascada jerárquica y no
/// forman parte del contrato de Catalog; se almacenan aquí para consolidar
/// el estado compartido de filtros.
class AcademicHierarchySelection {
  final String? universityId;
  final String? careerId;
  final String? subjectId;
  final String? professorId;

  // Niveles adicionales que NO pertenecen al contrato de Catalog
  final int? academicYear;
  final String? materialType;

  const AcademicHierarchySelection({
    this.universityId,
    this.careerId,
    this.subjectId,
    this.professorId,
    this.academicYear,
    this.materialType,
  });

  const AcademicHierarchySelection.empty()
    : universityId = null,
      careerId = null,
      subjectId = null,
      professorId = null,
      academicYear = null,
      materialType = null;

  bool get isEmpty =>
      (universityId == null || universityId!.isEmpty) &&
      (careerId == null || careerId!.isEmpty) &&
      (subjectId == null || subjectId!.isEmpty) &&
      (professorId == null || professorId!.isEmpty) &&
      academicYear == null &&
      (materialType == null || materialType!.isEmpty);

  bool get isNotEmpty => !isEmpty;

  AcademicHierarchySelection copyWith({
    String? universityId,
    String? careerId,
    String? subjectId,
    String? professorId,
    int? academicYear,
    String? materialType,
    bool clearUniversity = false,
    bool clearCareer = false,
    bool clearSubject = false,
    bool clearProfessor = false,
    bool clearYear = false,
    bool clearAcademicYear = false,
    bool clearType = false,
    bool clearMaterialType = false,
  }) {
    return AcademicHierarchySelection(
      universityId: clearUniversity
          ? null
          : (universityId ?? this.universityId),
      careerId: clearCareer ? null : (careerId ?? this.careerId),
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      professorId: clearProfessor ? null : (professorId ?? this.professorId),
      academicYear: (clearYear || clearAcademicYear)
          ? null
          : (academicYear ?? this.academicYear),
      materialType: (clearType || clearMaterialType)
          ? null
          : (materialType ?? this.materialType),
    );
  }

  /// Serializa la selección académica como parámetros de consulta HTTP.
  /// Año y Tipo se incluyen aquí pero NO pertenecen al contrato de Catalog.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (universityId != null && universityId!.trim().isNotEmpty) {
      params['universityId'] = universityId!.trim();
    }
    if (careerId != null && careerId!.trim().isNotEmpty) {
      params['careerId'] = careerId!.trim();
    }
    if (subjectId != null && subjectId!.trim().isNotEmpty) {
      params['subjectId'] = subjectId!.trim();
    }
    if (professorId != null && professorId!.trim().isNotEmpty) {
      params['professorId'] = professorId!.trim();
    }
    if (academicYear != null) {
      params['year'] = academicYear.toString();
    }
    if (materialType != null && materialType!.trim().isNotEmpty) {
      params['type'] = materialType!.trim();
    }
    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcademicHierarchySelection &&
          runtimeType == other.runtimeType &&
          universityId == other.universityId &&
          careerId == other.careerId &&
          subjectId == other.subjectId &&
          professorId == other.professorId &&
          academicYear == other.academicYear &&
          materialType == other.materialType;

  @override
  int get hashCode =>
      universityId.hashCode ^
      careerId.hashCode ^
      subjectId.hashCode ^
      professorId.hashCode ^
      academicYear.hashCode ^
      materialType.hashCode;

  @override
  String toString() =>
      'AcademicHierarchySelection(universityId: $universityId, '
      'careerId: $careerId, subjectId: $subjectId, professorId: $professorId, '
      'academicYear: $academicYear, materialType: $materialType)';
}

// ---------------------------------------------------------------------------
// AcademicHierarchyState
// ---------------------------------------------------------------------------

/// Estado inmutable que gestiona la clasificación jerárquica y entidades
/// activas para los 6 niveles (Issues #281, #282 y #289).
class AcademicHierarchyState {
  static const List<int> defaultYears = [2026, 2025, 2024, 2023, 2022, 2021];
  static const List<String> defaultTypes = [
    'apunte',
    'certamen',
    'guia',
    'prueba',
    'examen',
    'control',
    'resumen',
    'formulario',
  ];

  final AcademicHierarchySelection selection;

  // Listas de entidades disponibles en memoria
  final List<UniversityModel> universities;
  final List<CareerModel> careers;
  final List<SubjectModel> subjects;
  final List<ProfessorModel> professors;

  /// Años académicos disponibles para el selector (nivel 5).
  final List<int> availableYears;

  /// Tipos de material disponibles para el selector (nivel 6).
  final List<String> availableTypes;

  // Indicadores de carga por nivel
  final bool isLoadingUniversities;
  final bool isLoadingCareers;
  final bool isLoadingSubjects;
  final bool isLoadingProfessors;

  // Errores por nivel
  final String? errorUniversities;
  final String? errorCareers;
  final String? errorSubjects;
  final String? errorProfessors;

  const AcademicHierarchyState({
    this.selection = const AcademicHierarchySelection.empty(),
    this.universities = const [],
    this.careers = const [],
    this.subjects = const [],
    this.professors = const [],
    this.availableYears = defaultYears,
    this.availableTypes = defaultTypes,
    this.isLoadingUniversities = false,
    this.isLoadingCareers = false,
    this.isLoadingSubjects = false,
    this.isLoadingProfessors = false,
    this.errorUniversities,
    this.errorCareers,
    this.errorSubjects,
    this.errorProfessors,
  });

  // Accesores directos a IDs seleccionados
  String? get selectedUniversityId => selection.universityId;
  String? get selectedCareerId => selection.careerId;
  String? get selectedSubjectId => selection.subjectId;
  String? get selectedProfessorId => selection.professorId;
  int? get selectedYear => selection.academicYear;
  String? get selectedType => selection.materialType;

  bool get isUniversitySelected =>
      selectedUniversityId != null && selectedUniversityId!.isNotEmpty;
  bool get isCareerSelected =>
      selectedCareerId != null && selectedCareerId!.isNotEmpty;
  bool get isSubjectSelected =>
      selectedSubjectId != null && selectedSubjectId!.isNotEmpty;
  bool get isProfessorSelected =>
      selectedProfessorId != null && selectedProfessorId!.isNotEmpty;
  bool get isYearSelected => selectedYear != null;
  bool get isTypeSelected => selectedType != null && selectedType!.isNotEmpty;

  // Reglas de habilitación en cascada para la UI (Issue #282 y #289)
  bool get canSelectUniversity => !isLoadingUniversities;
  bool get canSelectCareer =>
      isUniversitySelected && !isLoadingCareers && errorCareers == null;
  bool get canSelectSubject =>
      isCareerSelected && !isLoadingSubjects && errorSubjects == null;
  bool get canSelectProfessor =>
      isSubjectSelected && !isLoadingProfessors && errorProfessors == null;
  bool get canSelectYear => true;
  bool get canSelectType => true;

  // Objetos completos seleccionados (si se encuentran en las listas actuales)
  UniversityModel? get selectedUniversity {
    if (!isUniversitySelected) return null;
    return universities
        .where((u) => u.id == selectedUniversityId)
        .cast<UniversityModel?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  CareerModel? get selectedCareer {
    if (!isCareerSelected) return null;
    return careers
        .where((c) => c.id == selectedCareerId)
        .cast<CareerModel?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  SubjectModel? get selectedSubject {
    if (!isSubjectSelected) return null;
    return subjects
        .where((s) => s.id == selectedSubjectId)
        .cast<SubjectModel?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  ProfessorModel? get selectedProfessor {
    if (!isProfessorSelected) return null;
    return professors
        .where((p) => p.id == selectedProfessorId)
        .cast<ProfessorModel?>()
        .firstWhere((_) => true, orElse: () => null);
  }

  // Estados agregados
  bool get isAnyLoading =>
      isLoadingUniversities ||
      isLoadingCareers ||
      isLoadingSubjects ||
      isLoadingProfessors;

  bool get hasAnyError =>
      errorUniversities != null ||
      errorCareers != null ||
      errorSubjects != null ||
      errorProfessors != null;

  bool get hasActiveFilters => selection.isNotEmpty;

  int get activeFiltersCount {
    var count = 0;
    if (isUniversitySelected) count++;
    if (isCareerSelected) count++;
    if (isSubjectSelected) count++;
    if (isProfessorSelected) count++;
    if (selectedYear != null) count++;
    if (selectedType != null && selectedType!.isNotEmpty) count++;
    return count;
  }

  Map<String, String> toQueryParams() => selection.toQueryParams();

  AcademicHierarchyState copyWith({
    AcademicHierarchySelection? selection,
    List<UniversityModel>? universities,
    List<CareerModel>? careers,
    List<SubjectModel>? subjects,
    List<ProfessorModel>? professors,
    List<int>? availableYears,
    List<String>? availableTypes,
    bool? isLoadingUniversities,
    bool? isLoadingCareers,
    bool? isLoadingSubjects,
    bool? isLoadingProfessors,
    String? errorUniversities,
    bool clearErrorUniversities = false,
    String? errorCareers,
    bool clearErrorCareers = false,
    String? errorSubjects,
    bool clearErrorSubjects = false,
    String? errorProfessors,
    bool clearErrorProfessors = false,
  }) {
    return AcademicHierarchyState(
      selection: selection ?? this.selection,
      universities: universities ?? this.universities,
      careers: careers ?? this.careers,
      subjects: subjects ?? this.subjects,
      professors: professors ?? this.professors,
      availableYears: availableYears ?? this.availableYears,
      availableTypes: availableTypes ?? this.availableTypes,
      isLoadingUniversities:
          isLoadingUniversities ?? this.isLoadingUniversities,
      isLoadingCareers: isLoadingCareers ?? this.isLoadingCareers,
      isLoadingSubjects: isLoadingSubjects ?? this.isLoadingSubjects,
      isLoadingProfessors: isLoadingProfessors ?? this.isLoadingProfessors,
      errorUniversities: clearErrorUniversities
          ? null
          : (errorUniversities ?? this.errorUniversities),
      errorCareers: clearErrorCareers
          ? null
          : (errorCareers ?? this.errorCareers),
      errorSubjects: clearErrorSubjects
          ? null
          : (errorSubjects ?? this.errorSubjects),
      errorProfessors: clearErrorProfessors
          ? null
          : (errorProfessors ?? this.errorProfessors),
    );
  }
}

// ---------------------------------------------------------------------------
// AcademicHierarchyNotifier
// ---------------------------------------------------------------------------

/// Notifier de Riverpod para controlar la jerarquía académica en cascada.
///
/// Recibe [IAcademicHierarchyRepository] como dependencia a través del
/// [Ref], lo que permite sobrescribir el provider en tests con un
/// repositorio fake sin modificar este código.
class AcademicHierarchyNotifier extends Notifier<AcademicHierarchyState> {
  IAcademicHierarchyRepository get _repo =>
      ref.read(academicHierarchyRepositoryProvider);

  // -------------------------------------------------------------------------
  // Contadores de generación — descartan respuestas obsoletas (race condition)
  // -------------------------------------------------------------------------

  /// Incrementa cada vez que se inicia una nueva petición de carreras.
  /// La respuesta sólo se aplica si el contador no cambió durante el await.
  int _careersGen = 0;

  /// Idem para asignaturas.
  int _subjectsGen = 0;

  /// Idem para profesores.
  int _professorsGen = 0;

  @override
  AcademicHierarchyState build() => const AcademicHierarchyState();

  // -------------------------------------------------------------------------
  // Carga inicial y reintentos de universidades
  // -------------------------------------------------------------------------

  /// Carga las universidades desde el repositorio.
  Future<void> loadUniversities() async {
    state = state.copyWith(
      isLoadingUniversities: true,
      clearErrorUniversities: true,
    );
    try {
      final list = await _repo.fetchUniversities();
      state = state.copyWith(universities: list, isLoadingUniversities: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingUniversities: false,
        errorUniversities: 'No se pudieron cargar las universidades: $e',
      );
    }
  }

  /// Reintenta la carga de universidades ante un error de red.
  Future<void> retryUniversities() async => loadUniversities();

  // -------------------------------------------------------------------------
  // Selecciones en cascada — Fix: resetean loading y datos de niveles hijos
  // -------------------------------------------------------------------------

  /// Selecciona una universidad y reinicia selecciones, listas e indicadores
  /// de carga de los niveles hijos, luego carga las carreras del repositorio.
  /// Preserva campos no relacionados (Año y Tipo).
  Future<void> selectUniversity(String? universityId) async {
    if (state.selectedUniversityId == universityId) return;

    final validId = (universityId != null && universityId.trim().isNotEmpty)
        ? universityId.trim()
        : null;

    // Invalida cualquier petición de carreras/asignaturas/profesores en vuelo.
    final myGen = ++_careersGen;
    _subjectsGen++;
    _professorsGen++;

    // Reset inmediato: limpia hijos, errores Y loadings de niveles hijo
    state = state.copyWith(
      selection: AcademicHierarchySelection(
        universityId: validId,
        academicYear: state.selection.academicYear,
        materialType: state.selection.materialType,
      ),
      careers: const [],
      subjects: const [],
      professors: const [],
      isLoadingCareers: false,
      isLoadingSubjects: false,
      isLoadingProfessors: false,
      clearErrorCareers: true,
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );

    if (validId == null) return;

    state = state.copyWith(isLoadingCareers: true);
    try {
      final careers = await _repo.fetchCareersByUniversity(validId);
      // Descarta la respuesta si el usuario ya seleccionó otra universidad.
      if (_careersGen != myGen) return;
      state = state.copyWith(careers: careers, isLoadingCareers: false);
    } catch (e) {
      if (_careersGen != myGen) return;
      state = state.copyWith(
        isLoadingCareers: false,
        errorCareers: 'No se pudieron cargar las carreras: $e',
      );
    }
  }

  /// Reintenta la carga de carreras para la universidad seleccionada.
  /// Preserva campos no relacionados (Año y Tipo).
  Future<void> retryCareers() async {
    final uniId = state.selectedUniversityId;
    if (uniId == null) return;

    final myGen = ++_careersGen;
    state = state.copyWith(
      isLoadingCareers: true,
      clearErrorCareers: true,
    );
    try {
      final careers = await _repo.fetchCareersByUniversity(uniId);
      if (_careersGen != myGen) return;
      state = state.copyWith(careers: careers, isLoadingCareers: false);
    } catch (e) {
      if (_careersGen != myGen) return;
      state = state.copyWith(
        isLoadingCareers: false,
        errorCareers: 'No se pudieron cargar las carreras: $e',
      );
    }
  }

  /// Selecciona una carrera y reinicia asignaturas, profesores e indicadores
  /// de carga de niveles hijos, luego carga las asignaturas del repositorio.
  /// Preserva campos no relacionados (Universidad, Año, Tipo).
  Future<void> selectCareer(String? careerId) async {
    if (state.selectedCareerId == careerId) return;

    final validId = (careerId != null && careerId.trim().isNotEmpty)
        ? careerId.trim()
        : null;

    // Invalida peticiones de asignaturas/profesores en vuelo.
    final myGen = ++_subjectsGen;
    _professorsGen++;

    state = state.copyWith(
      selection: state.selection.copyWith(
        careerId: validId,
        clearCareer: validId == null,
        clearSubject: true,
        clearProfessor: true,
      ),
      subjects: const [],
      professors: const [],
      isLoadingSubjects: false,
      isLoadingProfessors: false,
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );

    if (validId == null) return;

    state = state.copyWith(isLoadingSubjects: true);
    try {
      final subjects = await _repo.fetchSubjectsByCareer(validId);
      // Descarta la respuesta si el usuario ya seleccionó otra carrera.
      if (_subjectsGen != myGen) return;
      state = state.copyWith(subjects: subjects, isLoadingSubjects: false);
    } catch (e) {
      if (_subjectsGen != myGen) return;
      state = state.copyWith(
        isLoadingSubjects: false,
        errorSubjects: 'No se pudieron cargar las asignaturas: $e',
      );
    }
  }

  /// Reintenta la carga de asignaturas para la carrera seleccionada.
  /// Preserva campos no relacionados (Universidad, Carrera, Año, Tipo).
  Future<void> retrySubjects() async {
    final careerId = state.selectedCareerId;
    if (careerId == null) return;

    final myGen = ++_subjectsGen;
    state = state.copyWith(
      isLoadingSubjects: true,
      clearErrorSubjects: true,
    );
    try {
      final subjects = await _repo.fetchSubjectsByCareer(careerId);
      if (_subjectsGen != myGen) return;
      state = state.copyWith(subjects: subjects, isLoadingSubjects: false);
    } catch (e) {
      if (_subjectsGen != myGen) return;
      state = state.copyWith(
        isLoadingSubjects: false,
        errorSubjects: 'No se pudieron cargar las asignaturas: $e',
      );
    }
  }

  /// Selecciona una asignatura y reinicia el profesor e indicador de carga
  /// del nivel hijo, luego carga los profesores del repositorio.
  /// Preserva campos no relacionados (Universidad, Carrera, Año, Tipo).
  Future<void> selectSubject(String? subjectId) async {
    if (state.selectedSubjectId == subjectId) return;

    final validId = (subjectId != null && subjectId.trim().isNotEmpty)
        ? subjectId.trim()
        : null;

    // Invalida peticiones de profesores en vuelo.
    final myGen = ++_professorsGen;

    state = state.copyWith(
      selection: state.selection.copyWith(
        subjectId: validId,
        clearSubject: validId == null,
        clearProfessor: true,
      ),
      professors: const [],
      isLoadingProfessors: false,
      clearErrorProfessors: true,
    );

    if (validId == null) return;

    state = state.copyWith(isLoadingProfessors: true);
    try {
      final professors = await _repo.fetchProfessorsBySubject(validId);
      // Descarta la respuesta si el usuario ya seleccionó otra asignatura.
      if (_professorsGen != myGen) return;
      state = state.copyWith(professors: professors, isLoadingProfessors: false);
    } catch (e) {
      if (_professorsGen != myGen) return;
      state = state.copyWith(
        isLoadingProfessors: false,
        errorProfessors: 'No se pudieron cargar los profesores: $e',
      );
    }
  }

  /// Reintenta la carga de profesores para la asignatura seleccionada.
  /// Preserva campos no relacionados (Universidad, Carrera, Asignatura, Año, Tipo).
  Future<void> retryProfessors() async {
    final subjId = state.selectedSubjectId;
    if (subjId == null) return;

    final myGen = ++_professorsGen;
    state = state.copyWith(
      isLoadingProfessors: true,
      clearErrorProfessors: true,
    );
    try {
      final professors = await _repo.fetchProfessorsBySubject(subjId);
      if (_professorsGen != myGen) return;
      state = state.copyWith(professors: professors, isLoadingProfessors: false);
    } catch (e) {
      if (_professorsGen != myGen) return;
      state = state.copyWith(
        isLoadingProfessors: false,
        errorProfessors: 'No se pudieron cargar los profesores: $e',
      );
    }
  }

  /// Selecciona o deselecciona un profesor.
  void selectProfessor(String? professorId) {
    if (state.selectedProfessorId == professorId) return;

    final validId = (professorId != null && professorId.trim().isNotEmpty)
        ? professorId.trim()
        : null;

    state = state.copyWith(
      selection: state.selection.copyWith(
        professorId: validId,
        clearProfessor: validId == null,
      ),
    );
  }

  /// Selecciona o limpia el año académico (nivel 5).
  void selectYear(int? year) {
    if (state.selection.academicYear == year) return;
    state = state.copyWith(
      selection: state.selection.copyWith(
        academicYear: year,
        clearYear: year == null,
        clearAcademicYear: year == null,
      ),
    );
  }

  /// Selecciona o limpia el tipo de material (nivel 6).
  void selectType(String? type) {
    if (state.selection.materialType == type) return;
    final validType = (type != null && type.trim().isNotEmpty)
        ? type.trim()
        : null;
    state = state.copyWith(
      selection: state.selection.copyWith(
        materialType: validType,
        clearType: validType == null,
        clearMaterialType: validType == null,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resets
  // -------------------------------------------------------------------------

  /// Reinicia la selección activa manteniendo universidades cargadas.
  /// También limpia todos los loadings y errores de niveles hijos.
  void resetSelection() {
    // Invalida cualquier petición async pendiente antes de limpiar.
    _careersGen++;
    _subjectsGen++;
    _professorsGen++;
    state = state.copyWith(
      selection: const AcademicHierarchySelection.empty(),
      careers: const [],
      subjects: const [],
      professors: const [],
      isLoadingCareers: false,
      isLoadingSubjects: false,
      isLoadingProfessors: false,
      clearErrorCareers: true,
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );
  }

  /// Reinicia todo el estado a valores iniciales por defecto.
  void resetAll() {
    // Invalida cualquier petición async pendiente antes de limpiar.
    _careersGen++;
    _subjectsGen++;
    _professorsGen++;
    state = const AcademicHierarchyState();
  }

  // -------------------------------------------------------------------------
  // Setters directos (para tests de integración ligeros o inicialización)
  // -------------------------------------------------------------------------

  void setUniversities(List<UniversityModel> list) {
    state = state.copyWith(universities: list);
  }

  void setCareers(List<CareerModel> list) {
    state = state.copyWith(careers: list);
  }

  void setSubjects(List<SubjectModel> list) {
    state = state.copyWith(subjects: list);
  }

  void setProfessors(List<ProfessorModel> list) {
    state = state.copyWith(professors: list);
  }

  void setLoadingUniversities(bool loading) {
    state = state.copyWith(isLoadingUniversities: loading);
  }

  void setLoadingCareers(bool loading) {
    state = state.copyWith(isLoadingCareers: loading);
  }

  void setLoadingSubjects(bool loading) {
    state = state.copyWith(isLoadingSubjects: loading);
  }

  void setLoadingProfessors(bool loading) {
    state = state.copyWith(isLoadingProfessors: loading);
  }

  void setErrorUniversities(String? error) {
    state = state.copyWith(
      errorUniversities: error,
      clearErrorUniversities: error == null,
    );
  }

  void setErrorCareers(String? error) {
    state = state.copyWith(
      errorCareers: error,
      clearErrorCareers: error == null,
    );
  }

  void setErrorSubjects(String? error) {
    state = state.copyWith(
      errorSubjects: error,
      clearErrorSubjects: error == null,
    );
  }

  void setErrorProfessors(String? error) {
    state = state.copyWith(
      errorProfessors: error,
      clearErrorProfessors: error == null,
    );
  }

  /// Carga datos mock para pruebas locales de UI o prototipado.
  void loadMockHierarchy() {
    state = state.copyWith(
      universities: UniversityModel.mockList(),
      careers: CareerModel.mockList(),
      subjects: SubjectModel.mockList(),
      professors: ProfessorModel.mockList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provider principal de Riverpod para gestionar la jerarquía académica.
final academicHierarchyProvider =
    NotifierProvider<AcademicHierarchyNotifier, AcademicHierarchyState>(
      AcademicHierarchyNotifier.new,
    );

/// Provider computado que indica si hay algún filtro jerárquico activo.
final hasAcademicHierarchyFiltersProvider = Provider<bool>((ref) {
  return ref.watch(academicHierarchyProvider).hasActiveFilters;
});