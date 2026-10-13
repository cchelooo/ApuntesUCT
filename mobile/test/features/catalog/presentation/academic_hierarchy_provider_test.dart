import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<List<CareerModel>> fetchCareersByUniversity(String universityId) async =>
      CareerModel.mockList();

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      SubjectModel.mockList();

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(String subjectId) async =>
      ProfessorModel.mockList();
}

class _FakeErrorRepo implements IAcademicHierarchyRepository {
  @override
  Future<List<UniversityModel>> fetchUniversities() async =>
      throw Exception('Error de red en universidades');

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(String universityId) async =>
      throw Exception('Error de red en carreras');

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      throw Exception('Error de red en asignaturas');

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(String subjectId) async =>
      throw Exception('Error de red en profesores');
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
  group('AcademicHierarchyProvider Tests (Issue #281)', () {
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

    test(
      'selectUniversity carga carreras y resetea loadings hijos',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        // Precondicion: simular un loading previo en carreras (carga anterior)
        notifier.setLoadingCareers(true);
        notifier.setLoadingSubjects(true);

        await notifier.selectUniversity('uct-main-uuid');
        final state = container.read(academicHierarchyProvider);

        expect(state.selectedUniversityId, 'uct-main-uuid');
        expect(state.selectedCareerId, isNull);
        expect(state.selectedSubjectId, isNull);
        expect(state.selectedProfessorId, isNull);

        // Debe haber cargado las carreras desde el repo
        expect(state.careers, isNotEmpty);
        expect(state.isLoadingCareers, isFalse);
        expect(state.isLoadingSubjects, isFalse);
        expect(state.isLoadingProfessors, isFalse);
        expect(state.canSelectCareer, isTrue);
      },
    );

    test(
      'selectUniversity con repositorio fallido registra errorCareers',
      () async {
        final errorContainer = _makeContainer(repo: _FakeErrorRepo());
        addTearDown(errorContainer.dispose);

        await errorContainer
            .read(academicHierarchyProvider.notifier)
            .selectUniversity('uct-main-uuid');
        final state = errorContainer.read(academicHierarchyProvider);

        expect(state.isLoadingCareers, isFalse);
        expect(state.errorCareers, contains('Error de red en carreras'));
        expect(state.careers, isEmpty);
      },
    );

    test(
      'selectUniversity reinicia en cascada selecciones y listas hijas',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        // Seleccion completa previa
        await notifier.selectUniversity('uct-main-uuid');
        await notifier.selectCareer('career-inf-uuid');
        await notifier.selectSubject('subj-integra-iv-uuid');
        notifier.selectProfessor('prof-mellado-uuid');

        var state = container.read(academicHierarchyProvider);
        expect(state.selectedProfessorId, 'prof-mellado-uuid');

        // Cambiar universidad: debe reiniciar todo lo hijos
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
      },
    );

    // -----------------------------------------------------------------------
    // selectCareer — via repositorio
    // -----------------------------------------------------------------------

    test('selectCareer carga asignaturas y resetea loadings hijos', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');

      notifier.setLoadingSubjects(true);
      notifier.setLoadingProfessors(true);

      await notifier.selectCareer('career-inf-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedCareerId, 'career-inf-uuid');
      expect(state.subjects, isNotEmpty);
      expect(state.isLoadingSubjects, isFalse);
      expect(state.isLoadingProfessors, isFalse);
    });

    test(
      'selectCareer con repositorio fallido registra errorSubjects',
      () async {
        final errorContainer = _makeContainer(repo: _FakeErrorRepo());
        addTearDown(errorContainer.dispose);

        // Forzar universidad seleccionada para poder llamar selectCareer
        errorContainer
            .read(academicHierarchyProvider.notifier)
            .setUniversities(UniversityModel.mockList());
        errorContainer
            .read(academicHierarchyProvider.notifier)
            .setLoadingUniversities(false);

        await errorContainer
            .read(academicHierarchyProvider.notifier)
            .selectCareer('career-inf-uuid');
        final state = errorContainer.read(academicHierarchyProvider);

        expect(state.isLoadingSubjects, isFalse);
        expect(state.errorSubjects, contains('Error de red en asignaturas'));
        expect(state.subjects, isEmpty);
      },
    );

    test('selectCareer reinicia asignatura y profesor', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('carrera-1');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      await notifier.selectCareer('carrera-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedCareerId, 'carrera-2');
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
      await notifier.selectCareer('career-inf-uuid');

      notifier.setLoadingProfessors(true);

      await notifier.selectSubject('subj-integra-iv-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'subj-integra-iv-uuid');
      expect(state.professors, isNotEmpty);
      expect(state.isLoadingProfessors, isFalse);
    });

    test(
      'selectSubject con repositorio fallido registra errorProfessors',
      () async {
        final errorContainer = _makeContainer(repo: _FakeErrorRepo());
        addTearDown(errorContainer.dispose);

        await errorContainer
            .read(academicHierarchyProvider.notifier)
            .selectSubject('subj-integra-iv-uuid');
        final state = errorContainer.read(academicHierarchyProvider);

        expect(state.isLoadingProfessors, isFalse);
        expect(state.errorProfessors, contains('Error de red en profesores'));
        expect(state.professors, isEmpty);
      },
    );

    test('selectSubject reinicia profesor y carga profesores del nuevo padre', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('carrera-1');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      await notifier.selectSubject('ramo-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'ramo-2');
      // El profesor previo queda anulado antes de la carga
      expect(state.selectedProfessorId, isNull);
      // Tras la carga asincrona el repo devuelve los profesores del nuevo padre
      expect(state.professors, isNotEmpty);
      expect(state.isLoadingProfessors, isFalse);
    });

    // -----------------------------------------------------------------------
    // selectProfessor
    // -----------------------------------------------------------------------

    test('selectProfessor actualiza unicamente el profesor', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('carrera-1');
      await notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');
      notifier.selectProfessor('prof-2');

      final state = container.read(academicHierarchyProvider);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'carrera-1');
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
        // Fix: loadings deben quedar en false tras reset
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

    test(
      'hasAcademicHierarchyFiltersProvider reacciona reactivamente',
      () async {
        expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);

        await container
            .read(academicHierarchyProvider.notifier)
            .selectUniversity('u1');
        expect(container.read(hasAcademicHierarchyFiltersProvider), isTrue);

        container
            .read(academicHierarchyProvider.notifier)
            .resetSelection();
        expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);
      },
    );
  });
}