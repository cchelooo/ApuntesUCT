import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/models/models.dart';

// ---------------------------------------------------------------------------
// Fakes para tests
// ---------------------------------------------------------------------------

class _FakeSuccessRepo implements IAcademicHierarchyRepository {
  @override
  Future<List<UniversityModel>> fetchUniversities() async =>
      UniversityModel.mockList();

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(
    String universityId,
  ) async =>
      CareerModel.mockList()
          .where((c) => c.universityId == universityId)
          .toList();

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      SubjectModel.mockList();

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(
    String subjectId,
  ) async =>
      ProfessorModel.mockList();
}

class _FakeControllableRepo implements IAcademicHierarchyRepository {
  FutureOr<List<CareerModel>> Function(String)? onFetchCareers;

  @override
  Future<List<UniversityModel>> fetchUniversities() async =>
      UniversityModel.mockList();

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(
    String universityId,
  ) async {
    if (onFetchCareers != null) return onFetchCareers!(universityId);
    return CareerModel.mockList()
        .where((c) => c.universityId == universityId)
        .toList();
  }

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      SubjectModel.mockList();

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(
    String subjectId,
  ) async =>
      ProfessorModel.mockList();
}

class _FakeErrorRepo implements IAcademicHierarchyRepository {
  @override
  Future<List<UniversityModel>> fetchUniversities() async =>
      throw Exception('Error de red en universidades');

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(
    String universityId,
  ) async =>
      throw Exception('Error de red en carreras');

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      throw Exception('Error de red en asignaturas');

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(
    String subjectId,
  ) async =>
      throw Exception('Error de red en profesores');
}

/// Repositorio sustituible para simular respuestas vacías, errores de red
/// y reintentos en pruebas unitarias del provider (Issue #289).
class FakeAcademicHierarchyRepository implements IAcademicHierarchyRepository {
  FutureOr<List<UniversityModel>> Function()? onFetchUniversities;
  FutureOr<List<CareerModel>> Function(String universityId)? onFetchCareers;
  FutureOr<List<SubjectModel>> Function(String careerId)? onFetchSubjects;
  FutureOr<List<ProfessorModel>> Function(String subjectId)? onFetchProfessors;

  @override
  Future<List<UniversityModel>> fetchUniversities() async {
    if (onFetchUniversities != null) return onFetchUniversities!();
    return UniversityModel.mockList();
  }

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(
    String universityId,
  ) async {
    if (onFetchCareers != null) return onFetchCareers!(universityId);
    return CareerModel.mockList()
        .where((c) => c.universityId == universityId)
        .toList();
  }

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async {
    if (onFetchSubjects != null) return onFetchSubjects!(careerId);
    return SubjectModel.mockList();
  }

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(
    String subjectId,
  ) async {
    if (onFetchProfessors != null) return onFetchProfessors!(subjectId);
    return ProfessorModel.mockList();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({IAcademicHierarchyRepository? repo}) {
  return ProviderContainer(
    overrides: [
      if (repo != null)
        academicHierarchyRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('AcademicHierarchyProvider Tests (Issue #281 & #326)', () {
    late ProviderContainer container;

    setUp(() {
      container = _makeContainer(repo: _FakeSuccessRepo());
    });

    tearDown(() {
      container.dispose();
    });

    // -----------------------------------------------------------------------
    // Estado inicial
    // -----------------------------------------------------------------------

    test('Estado inicial esta vacio y sin errores de carga', () {
      final state = container.read(academicHierarchyProvider);

      expect(state.selection.isEmpty, isTrue);
      expect(state.selection.isNotEmpty, isFalse);
      expect(state.selectedUniversityId, isNull);
      expect(state.selectedCareerId, isNull);
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.selectedYear, isNull);
      expect(state.selectedType, isNull);

      expect(state.universities, isEmpty);
      expect(state.careers, isEmpty);
      expect(state.subjects, isEmpty);
      expect(state.professors, isEmpty);

      expect(state.isAnyLoading, isFalse);
      expect(state.hasAnyError, isFalse);
      expect(state.hasActiveFilters, isFalse);

      expect(state.canSelectUniversity, isTrue);
      expect(state.canSelectCareer, isFalse);
      expect(state.canSelectSubject, isFalse);
      expect(state.canSelectProfessor, isFalse);
    });

    // -----------------------------------------------------------------------
    // loadUniversities — via repositorio
    // -----------------------------------------------------------------------

    test('loadUniversities carga universidades desde el repositorio', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.loadUniversities();
      final state = container.read(academicHierarchyProvider);

      expect(state.isLoadingUniversities, isFalse);
      expect(state.errorUniversities, isNull);
      expect(state.universities, isNotEmpty);
    });

    test('loadUniversities registra error cuando el repositorio falla', () async {
      final errorContainer = _makeContainer(repo: _FakeErrorRepo());
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(academicHierarchyProvider.notifier)
          .loadUniversities();
      final state = errorContainer.read(academicHierarchyProvider);

      expect(state.isLoadingUniversities, isFalse);
      expect(state.errorUniversities, contains('Error de red en universidades'));
      expect(state.universities, isEmpty);
    });

    // -----------------------------------------------------------------------
    // selectUniversity — via repositorio (fix cascada + loading hijos)
    // -----------------------------------------------------------------------

    test('selectUniversity carga carreras y resetea loadings hijos', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.setLoadingCareers(true);
      notifier.setLoadingSubjects(true);

      await notifier.selectUniversity('uct-main-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, isNull);
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);

      expect(state.careers, isNotEmpty);
      expect(state.isLoadingCareers, isFalse);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.isLoadingProfessors, isFalse);
      expect(state.canSelectCareer, isTrue);
    });

    test('selectUniversity con repositorio fallido registra errorCareers', () async {
      final errorContainer = _makeContainer(repo: _FakeErrorRepo());
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(academicHierarchyProvider.notifier)
          .selectUniversity('uct-main-uuid');
      final state = errorContainer.read(academicHierarchyProvider);

      expect(state.isLoadingCareers, isFalse);
      expect(state.errorCareers, contains('Error de red en carreras'));
      expect(state.careers, isEmpty);
    });

    test('selectUniversity reinicia en cascada selecciones y listas hijas', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('subj-integra-iv-uuid');
      notifier.selectProfessor('prof-mellado-uuid');

      var state = container.read(academicHierarchyProvider);
      expect(state.selectedProfessorId, 'prof-mellado-uuid');

      await notifier.selectUniversity('otra-uni-uuid');
      state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'otra-uni-uuid');
      expect(state.selectedCareerId, isNull);
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.subjects, isEmpty);
      expect(state.professors, isEmpty);
      expect(state.canSelectSubject, isFalse);
      expect(state.canSelectProfessor, isFalse);
    });

    // -----------------------------------------------------------------------
    // selectCareer — via repositorio
    // -----------------------------------------------------------------------

    test('selectCareer carga asignaturas y resetea loadings hijos', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');

      notifier.setLoadingSubjects(true);
      notifier.setLoadingProfessors(true);

      await notifier.selectCareer('inf-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.subjects, isNotEmpty);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.isLoadingProfessors, isFalse);
    });

    test('selectCareer con repositorio fallido registra errorSubjects', () async {
      final errorContainer = _makeContainer(repo: _FakeErrorRepo());
      addTearDown(errorContainer.dispose);

      errorContainer
          .read(academicHierarchyProvider.notifier)
          .setUniversities(UniversityModel.mockList());
      errorContainer
          .read(academicHierarchyProvider.notifier)
          .setLoadingUniversities(false);

      await errorContainer
          .read(academicHierarchyProvider.notifier)
          .selectCareer('inf-uct-uuid');
      final state = errorContainer.read(academicHierarchyProvider);

      expect(state.isLoadingSubjects, isFalse);
      expect(state.errorSubjects, contains('Error de red en asignaturas'));
      expect(state.subjects, isEmpty);
    });

    test('selectCareer reinicia asignatura y profesor', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      await notifier.selectCareer('ind-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedCareerId, 'ind-uct-uuid');
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.professors, isEmpty);
    });

    // -----------------------------------------------------------------------
    // selectSubject — via repositorio
    // -----------------------------------------------------------------------

    test('selectSubject carga profesores y resetea loading hijo', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');

      notifier.setLoadingProfessors(true);

      await notifier.selectSubject('subj-integra-iv-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'subj-integra-iv-uuid');
      expect(state.professors, isNotEmpty);
      expect(state.isLoadingProfessors, isFalse);
    });

    test('selectSubject con repositorio fallido registra errorProfessors', () async {
      final errorContainer = _makeContainer(repo: _FakeErrorRepo());
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(academicHierarchyProvider.notifier)
          .selectSubject('subj-integra-iv-uuid');
      final state = errorContainer.read(academicHierarchyProvider);

      expect(state.isLoadingProfessors, isFalse);
      expect(state.errorProfessors, contains('Error de red en profesores'));
      expect(state.professors, isEmpty);
    });

    test('selectSubject reinicia profesor y carga profesores del nuevo padre', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      await notifier.selectSubject('ramo-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'ramo-2');
      expect(state.selectedProfessorId, isNull);
      expect(state.professors, isNotEmpty);
      expect(state.isLoadingProfessors, isFalse);
    });

    // -----------------------------------------------------------------------
    // selectProfessor
    // -----------------------------------------------------------------------

    test('selectProfessor actualiza unicamente el profesor', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');
      notifier.selectProfessor('prof-2');

      final state = container.read(academicHierarchyProvider);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.selectedSubjectId, 'ramo-1');
      expect(state.selectedProfessorId, 'prof-2');
    });

    // -----------------------------------------------------------------------
    // Anio y Tipo (niveles 5 y 6)
    // -----------------------------------------------------------------------

    test('selectYear y selectType actualizan los filtros opcionales', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectYear(2024);
      notifier.selectType('apunte');

      final state = container.read(academicHierarchyProvider);
      expect(state.selectedYear, 2024);
      expect(state.selectedType, 'apunte');
      expect(state.hasActiveFilters, isTrue);
    });

    test('selectYear y selectType con null limpian los filtros', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectYear(2024);
      notifier.selectType('prueba');
      notifier.selectYear(null);
      notifier.selectType(null);

      final state = container.read(academicHierarchyProvider);
      expect(state.selectedYear, isNull);
      expect(state.selectedType, isNull);
      expect(state.hasActiveFilters, isFalse);
    });

    test('Anio y Tipo NO se resetean al cambiar universidad', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectYear(2023);
      notifier.selectType('guia');
      await notifier.selectUniversity('uct-main-uuid');

      final state = container.read(academicHierarchyProvider);
      expect(state.selectedYear, 2023);
      expect(state.selectedType, 'guia');
    });

    // -----------------------------------------------------------------------
    // toQueryParams
    // -----------------------------------------------------------------------

    test('toQueryParams serializa correctamente los parametros no nulos', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      expect(container.read(academicHierarchyProvider).toQueryParams(), isEmpty);

      await notifier.selectUniversity('uct-uuid');
      await notifier.selectCareer('carr-uuid');
      expect(container.read(academicHierarchyProvider).toQueryParams(), {
        'universityId': 'uct-uuid',
        'careerId': 'carr-uuid',
      });

      await notifier.selectSubject('subj-uuid');
      notifier.selectProfessor('prof-uuid');
      notifier.selectYear(2024);
      notifier.selectType('apunte');

      expect(container.read(academicHierarchyProvider).toQueryParams(), {
        'universityId': 'uct-uuid',
        'careerId': 'carr-uuid',
        'subjectId': 'subj-uuid',
        'professorId': 'prof-uuid',
        'year': '2024',
        'type': 'apunte',
      });
    });

    // -----------------------------------------------------------------------
    // resetSelection
    // -----------------------------------------------------------------------

    test(
      'resetSelection limpia seleccion y loadings manteniendo universidades',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        await notifier.loadUniversities();
        await notifier.selectUniversity('uct-main-uuid');
        await notifier.selectCareer('career-inf-uuid');
        notifier.selectYear(2024);
        notifier.selectType('apunte');

        notifier.setLoadingCareers(true);
        notifier.setLoadingSubjects(true);

        notifier.resetSelection();
        final state = container.read(academicHierarchyProvider);

        expect(state.hasActiveFilters, isFalse);
        expect(state.selectedUniversityId, isNull);
        expect(state.selectedCareerId, isNull);
        expect(state.selectedYear, isNull);
        expect(state.selectedType, isNull);
        expect(state.universities, isNotEmpty);
        expect(state.careers, isEmpty);
        expect(state.isLoadingCareers, isFalse);
        expect(state.isLoadingSubjects, isFalse);
        expect(state.isLoadingProfessors, isFalse);
      },
    );

    // -----------------------------------------------------------------------
    // resetAll
    // -----------------------------------------------------------------------

    test('resetAll devuelve el estado a valores iniciales por defecto', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.loadUniversities();
      await notifier.selectUniversity('uct-main-uuid');

      notifier.resetAll();
      final state = container.read(academicHierarchyProvider);

      expect(state.universities, isEmpty);
      expect(state.selectedUniversityId, isNull);
    });

    // -----------------------------------------------------------------------
    // Gestion de estados de carga y error manuales
    // -----------------------------------------------------------------------

    test('Gestion de estados de carga y error por nivel via setters', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.setLoadingUniversities(true);
      expect(
        container.read(academicHierarchyProvider).isLoadingUniversities,
        isTrue,
      );
      expect(container.read(academicHierarchyProvider).isAnyLoading, isTrue);
      expect(
        container.read(academicHierarchyProvider).canSelectUniversity,
        isFalse,
      );

      notifier.setLoadingUniversities(false);
      notifier.setErrorUniversities('Error de red en universidades');
      expect(
        container.read(academicHierarchyProvider).errorUniversities,
        'Error de red en universidades',
      );
      expect(container.read(academicHierarchyProvider).hasAnyError, isTrue);

      notifier.setErrorUniversities(null);
      expect(container.read(academicHierarchyProvider).hasAnyError, isFalse);
    });

    // -----------------------------------------------------------------------
    // Provider computado reactivo
    // -----------------------------------------------------------------------

    test('hasAcademicHierarchyFiltersProvider reacciona reactivamente', () async {
      expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);

      await container
          .read(academicHierarchyProvider.notifier)
          .selectUniversity('u1');
      expect(container.read(hasAcademicHierarchyFiltersProvider), isTrue);

      container
          .read(academicHierarchyProvider.notifier)
          .resetSelection();
      expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);
    });

    // -----------------------------------------------------------------------
    // Race conditions y descarte de respuestas obsoletas (#326)
    // -----------------------------------------------------------------------

    test(
      'Descarta respuestas de red obsoletas ante cambios rápidos de universidad (#326)',
      () async {
        final slowCompleter = Completer<List<CareerModel>>();
        final repo = _FakeControllableRepo();
        repo.onFetchCareers = (uniId) {
          if (uniId == 'uni-lenta') return slowCompleter.future;
          return [
            const CareerModel(
              id: 'carrera-rapida',
              universityId: 'uni-rapida',
              name: 'Carrera Rápida',
              code: 'CR1',
              active: true,
            ),
          ];
        };

        final c = _makeContainer(repo: repo);
        addTearDown(c.dispose);
        final notifier = c.read(academicHierarchyProvider.notifier);

        final p1 = notifier.selectUniversity('uni-lenta');
        final p2 = notifier.selectUniversity('uni-rapida');

        await p2;
        var state = c.read(academicHierarchyProvider);
        expect(state.selectedUniversityId, 'uni-rapida');
        expect(state.careers.first.id, 'carrera-rapida');

        slowCompleter.complete([
          const CareerModel(
            id: 'carrera-lenta',
            universityId: 'uni-lenta',
            name: 'Carrera Lenta',
            code: 'CL1',
            active: true,
          ),
        ]);
        await p1;

        state = c.read(academicHierarchyProvider);
        expect(state.selectedUniversityId, 'uni-rapida');
        expect(state.careers.first.id, 'carrera-rapida');
      },
    );

    test(
      'Limpiar filtros mientras hay una petición en vuelo no permite que reaparezcan datos al completarse (#326)',
      () async {
        final slowCompleter = Completer<List<CareerModel>>();
        final repo = _FakeControllableRepo();
        repo.onFetchCareers = (uniId) => slowCompleter.future;

        final c = _makeContainer(repo: repo);
        addTearDown(c.dispose);
        final notifier = c.read(academicHierarchyProvider.notifier);

        final p = notifier.selectUniversity('uni-1');
        notifier.resetSelection();

        slowCompleter.complete([
          const CareerModel(
            id: 'c-1',
            universityId: 'uni-1',
            name: 'Carrera 1',
            code: 'C1',
            active: true,
          ),
        ]);
        await p;

        final state = c.read(academicHierarchyProvider);
        expect(state.careers, isEmpty);
        expect(state.selectedUniversityId, isNull);
      },
    );
  });

  group('AcademicHierarchyProvider Tests - Validación y Estados Parciales (Issue #289)', () {
    late FakeAcademicHierarchyRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAcademicHierarchyRepository();
      container = ProviderContainer(
        overrides: [
          academicHierarchyRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // -----------------------------------------------------------------------
    // Respuestas vacías
    // -----------------------------------------------------------------------

    test('Respuesta vacía en carreras no causa excepciones y bloquea selección de asignatura', () async {
      fakeRepo.onFetchCareers = (uniId) => [];

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uni-sin-carreras');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uni-sin-carreras');
      expect(state.careers, isEmpty);
      expect(state.isLoadingCareers, isFalse);
      expect(state.errorCareers, isNull);
      expect(state.canSelectCareer, isTrue);
      expect(state.canSelectSubject, isFalse);
    });

    test('Respuesta vacía en asignaturas y profesores maneja listas vacías correctamente', () async {
      fakeRepo.onFetchSubjects = (careerId) => [];
      fakeRepo.onFetchProfessors = (subjectId) => [];

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('carrera-sin-ramos');

      var state = container.read(academicHierarchyProvider);
      expect(state.subjects, isEmpty);
      expect(state.errorSubjects, isNull);
      expect(state.canSelectSubject, isTrue);
      expect(state.canSelectProfessor, isFalse);

      await notifier.selectSubject('ramo-sin-profes');
      state = container.read(academicHierarchyProvider);
      expect(state.professors, isEmpty);
      expect(state.errorProfessors, isNull);
    });

    // -----------------------------------------------------------------------
    // Errores de red por nivel
    // -----------------------------------------------------------------------

    test('Error de red en carreras registra mensaje indicando nivel "carreras"', () async {
      fakeRepo.onFetchCareers = (uniId) => throw Exception('Fallo de red en carreras');

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.careers, isEmpty);
      expect(state.isLoadingCareers, isFalse);
      expect(state.errorCareers, isNotNull);
      expect(state.errorCareers, contains('carreras'));
      expect(state.canSelectCareer, isFalse);
    });

    test('Error de red en asignaturas registra mensaje indicando nivel "asignaturas"', () async {
      fakeRepo.onFetchSubjects = (careerId) => throw Exception('Timeout asignaturas');

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.subjects, isEmpty);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.errorSubjects, isNotNull);
      expect(state.errorSubjects, contains('asignaturas'));
      expect(state.canSelectSubject, isFalse);
    });

    test('Error de red en profesores registra mensaje indicando nivel "profesores"', () async {
      fakeRepo.onFetchProfessors = (subjectId) => throw Exception('Timeout profesores');

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('subj-eda-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.professors, isEmpty);
      expect(state.isLoadingProfessors, isFalse);
      expect(state.errorProfessors, isNotNull);
      expect(state.errorProfessors, contains('profesores'));
      expect(state.canSelectProfessor, isFalse);
    });

    test('Error de red en universidades registra mensaje indicando nivel "universidades"', () async {
      fakeRepo.onFetchUniversities = () => throw Exception('Error 500 universidades');

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.loadUniversities();
      final state = container.read(academicHierarchyProvider);

      expect(state.universities, isEmpty);
      expect(state.isLoadingUniversities, isFalse);
      expect(state.errorUniversities, isNotNull);
      expect(state.errorUniversities, contains('universidades'));
    });

    // -----------------------------------------------------------------------
    // Reintentos y preservación de campos no relacionados
    // -----------------------------------------------------------------------

    test('retryCareers reintenta la carga y preserva universidad, año y tipo seleccionados', () async {
      var callCount = 0;
      fakeRepo.onFetchCareers = (uniId) {
        callCount++;
        if (callCount == 1) throw Exception('Fallo de red en carreras');
        return CareerModel.mockList();
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      notifier.selectYear(2024);
      notifier.selectType('resumen');

      await notifier.selectUniversity('uct-main-uuid');
      var state = container.read(academicHierarchyProvider);
      expect(state.errorCareers, isNotNull);
      expect(state.careers, isEmpty);

      await notifier.retryCareers();
      state = container.read(academicHierarchyProvider);

      expect(state.errorCareers, isNull);
      expect(state.careers, isNotEmpty);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedYear, 2024);
      expect(state.selectedType, 'resumen');
    });

    test('retrySubjects preserva universidad, carrera, año y tipo al reintentar', () async {
      var callCount = 0;
      fakeRepo.onFetchSubjects = (careerId) {
        callCount++;
        if (callCount == 1) throw Exception('Fallo de red en asignaturas');
        return SubjectModel.mockList();
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      notifier.selectYear(2023);
      notifier.selectType('control');

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      var state = container.read(academicHierarchyProvider);
      expect(state.errorSubjects, isNotNull);

      await notifier.retrySubjects();
      state = container.read(academicHierarchyProvider);

      expect(state.errorSubjects, isNull);
      expect(state.subjects, isNotEmpty);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.selectedYear, 2023);
      expect(state.selectedType, 'control');
    });

    // -----------------------------------------------------------------------
    // Criterio: Aislamiento de carreras por universidad (#289)
    // -----------------------------------------------------------------------

    test('Elegir UFRO devuelve solo sus propias carreras, no las de UCT', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      var state = container.read(academicHierarchyProvider);
      final uctCareerIds = state.careers.map((c) => c.id).toSet();
      expect(uctCareerIds, isNotEmpty);

      await notifier.selectUniversity('ufro-main-uuid');
      state = container.read(academicHierarchyProvider);

      expect(state.careers, isNotEmpty,
          reason: 'UFRO debe tener carreras propias en el mock');
      expect(
        state.careers.every((c) => c.universityId == 'ufro-main-uuid'),
        isTrue,
        reason: 'Todas las carreras deben pertenecer a UFRO',
      );

      final ufroCareerIds = state.careers.map((c) => c.id).toSet();
      expect(
        ufroCareerIds.intersection(uctCareerIds),
        isEmpty,
        reason: 'Las carreras de UCT no deben filtrarse con UFRO',
      );
    });

    test('Elegir universidad sin carreras en el mock devuelve lista vacía, no carreras de otra uni', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('desconocida-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(
        state.careers,
        isEmpty,
        reason: 'No debe haber fallback a carreras de otras universidades',
      );
      expect(state.canSelectCareer, isTrue);
      expect(state.canSelectSubject, isFalse);
    });
  });
}