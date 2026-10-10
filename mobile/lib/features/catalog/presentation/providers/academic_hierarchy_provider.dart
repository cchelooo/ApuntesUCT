import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';

/// Representa la selección académica actual en la jerarquía de 4 niveles.
class AcademicHierarchySelection {
  final String? universityId;
  final String? careerId;
  final String? subjectId;
  final String? professorId;

  const AcademicHierarchySelection({
    this.universityId,
    this.careerId,
    this.subjectId,
    this.professorId,
  });

  const AcademicHierarchySelection.empty()
    : universityId = null,
      careerId = null,
      subjectId = null,
      professorId = null;

  bool get isEmpty =>
      (universityId == null || universityId!.isEmpty) &&
      (careerId == null || careerId!.isEmpty) &&
      (subjectId == null || subjectId!.isEmpty) &&
      (professorId == null || professorId!.isEmpty);

  bool get isNotEmpty => !isEmpty;

  AcademicHierarchySelection copyWith({
    String? universityId,
    String? careerId,
    String? subjectId,
    String? professorId,
    bool clearUniversity = false,
    bool clearCareer = false,
    bool clearSubject = false,
    bool clearProfessor = false,
  }) {
    return AcademicHierarchySelection(
      universityId: clearUniversity
          ? null
          : (universityId ?? this.universityId),
      careerId: clearCareer ? null : (careerId ?? this.careerId),
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      professorId: clearProfessor ? null : (professorId ?? this.professorId),
    );
  }

  /// Serializa la selección académica como parámetros de consulta HTTP.
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
          professorId == other.professorId;

  @override
  int get hashCode =>
      universityId.hashCode ^
      careerId.hashCode ^
      subjectId.hashCode ^
      professorId.hashCode;

  @override
  String toString() =>
      'AcademicHierarchySelection(universityId: $universityId, careerId: $careerId, subjectId: $subjectId, professorId: $professorId)';
}

/// Estado inmutable que gestiona la clasificación jerárquica y entidades activas.
class AcademicHierarchyState {
  final AcademicHierarchySelection selection;

  // Listas de entidades disponibles en memoria
  final List<UniversityModel> universities;
  final List<CareerModel> careers;
  final List<SubjectModel> subjects;
  final List<ProfessorModel> professors;

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

  bool get isUniversitySelected =>
      selectedUniversityId != null && selectedUniversityId!.isNotEmpty;
  bool get isCareerSelected =>
      selectedCareerId != null && selectedCareerId!.isNotEmpty;
  bool get isSubjectSelected =>
      selectedSubjectId != null && selectedSubjectId!.isNotEmpty;
  bool get isProfessorSelected =>
      selectedProfessorId != null && selectedProfessorId!.isNotEmpty;

  // Reglas de habilitación en cascada para la UI (Issue #282 y #289)
  bool get canSelectUniversity => !isLoadingUniversities;
  bool get canSelectCareer => isUniversitySelected && !isLoadingCareers;
  bool get canSelectSubject => isCareerSelected && !isLoadingSubjects;
  bool get canSelectProfessor => isSubjectSelected && !isLoadingProfessors;

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

  Map<String, String> toQueryParams() => selection.toQueryParams();

  AcademicHierarchyState copyWith({
    AcademicHierarchySelection? selection,
    List<UniversityModel>? universities,
    List<CareerModel>? careers,
    List<SubjectModel>? subjects,
    List<ProfessorModel>? professors,
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

/// Notifier de Riverpod para controlar la jerarquía académica en cascada.
class AcademicHierarchyNotifier extends Notifier<AcademicHierarchyState> {
  @override
  AcademicHierarchyState build() {
    return const AcademicHierarchyState();
  }

  /// Selecciona una universidad y reinicia en cascada las selecciones y listas hijas.
  void selectUniversity(String? universityId) {
    if (state.selectedUniversityId == universityId) return;

    final validId = (universityId != null && universityId.trim().isNotEmpty)
        ? universityId.trim()
        : null;

    state = state.copyWith(
      selection: AcademicHierarchySelection(
        universityId: validId,
        careerId: null,
        subjectId: null,
        professorId: null,
      ),
      careers: const [],
      subjects: const [],
      professors: const [],
      clearErrorCareers: true,
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );
  }

  /// Selecciona una carrera y reinicia en cascada asignatura y profesor.
  void selectCareer(String? careerId) {
    if (state.selectedCareerId == careerId) return;

    final validId = (careerId != null && careerId.trim().isNotEmpty)
        ? careerId.trim()
        : null;

    state = state.copyWith(
      selection: state.selection.copyWith(
        careerId: validId,
        clearCareer: validId == null,
        clearSubject: true,
        clearProfessor: true,
      ),
      subjects: const [],
      professors: const [],
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );
  }

  /// Selecciona una asignatura y reinicia en cascada el profesor.
  void selectSubject(String? subjectId) {
    if (state.selectedSubjectId == subjectId) return;

    final validId = (subjectId != null && subjectId.trim().isNotEmpty)
        ? subjectId.trim()
        : null;

    state = state.copyWith(
      selection: state.selection.copyWith(
        subjectId: validId,
        clearSubject: validId == null,
        clearProfessor: true,
      ),
      professors: const [],
      clearErrorProfessors: true,
    );
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

  /// Reinicia la selección activa manteniendo la lista de universidades cargadas.
  void resetSelection() {
    state = state.copyWith(
      selection: const AcademicHierarchySelection.empty(),
      careers: const [],
      subjects: const [],
      professors: const [],
      clearErrorCareers: true,
      clearErrorSubjects: true,
      clearErrorProfessors: true,
    );
  }

  /// Reinicia todo el estado a valores iniciales por defecto.
  void resetAll() {
    state = const AcademicHierarchyState();
  }

  // --- Métodos mutadores para integración con repositorios o datos mock ---

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

/// Provider principal de Riverpod para gestionar la jerarquía académica.
final academicHierarchyProvider =
    NotifierProvider<AcademicHierarchyNotifier, AcademicHierarchyState>(
      AcademicHierarchyNotifier.new,
    );

/// Provider computado que indica si hay algún filtro jerárquico activo.
final hasAcademicHierarchyFiltersProvider = Provider<bool>((ref) {
  return ref.watch(academicHierarchyProvider).hasActiveFilters;
});
