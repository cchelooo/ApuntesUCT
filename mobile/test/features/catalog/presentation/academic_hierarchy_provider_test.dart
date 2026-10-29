import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/models/models.dart';

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
    // Filtra estrictamente — igual que el repositorio de producción.
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

void main() {
  group('AcademicHierarchyProvider Tests (Issue #281, #282 y #289)', () {
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
    // Estado inicial
    // -----------------------------------------------------------------------
    test('Estado inicial está vacío y sin errores de carga', () {
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
      expect(state.availableYears, isNotEmpty);
      expect(state.availableTypes, isNotEmpty);

      expect(state.isAnyLoading, isFalse);
      expect(state.hasAnyError, isFalse);
      expect(state.hasActiveFilters, isFalse);
      expect(state.activeFiltersCount, 0);

      expect(state.canSelectUniversity, isTrue);
      expect(state.canSelectCareer, isFalse);
      expect(state.canSelectSubject, isFalse);
      expect(state.canSelectProfessor, isFalse);
      expect(state.canSelectYear, isTrue);
      expect(state.canSelectType, isTrue);
    });

    // -----------------------------------------------------------------------
    // Criterio: Reseteo de filtros hijos
    // -----------------------------------------------------------------------
    test(
      'selectUniversity carga carreras del padre y reinicia selecciones y datos hijos',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        await notifier.loadUniversities();
        await notifier.selectUniversity('uct-main-uuid');
        var state = container.read(academicHierarchyProvider);

        expect(state.selectedUniversityId, 'uct-main-uuid');
        expect(state.selectedCareerId, isNull);
        expect(state.selectedSubjectId, isNull);
        expect(state.selectedProfessorId, isNull);
        expect(state.careers, isNotEmpty);
        expect(state.subjects, isEmpty);
        expect(state.professors, isEmpty);
        expect(state.canSelectCareer, isTrue);

        // Seleccionar carrera, asignatura y profesor
        await notifier.selectCareer(state.careers.first.id);
        state = container.read(academicHierarchyProvider);
        await notifier.selectSubject(state.subjects.first.id);
        state = container.read(academicHierarchyProvider);
        notifier.selectProfessor(state.professors.first.id);
        notifier.selectYear(2026);
        notifier.selectType('apunte');

        state = container.read(academicHierarchyProvider);
        expect(state.selectedProfessorId, isNotNull);
        expect(state.selectedYear, 2026);
        expect(state.selectedType, 'apunte');

        // Al cambiar de universidad, se reinician carrera, ramo y profesor
        // PERO se preservan Año y Tipo (campos no relacionados)
        await notifier.selectUniversity('otra-uni-uuid');
        state = container.read(academicHierarchyProvider);

        expect(state.selectedUniversityId, 'otra-uni-uuid');
        expect(state.selectedCareerId, isNull);
        expect(state.selectedSubjectId, isNull);
        expect(state.selectedProfessorId, isNull);
        expect(state.selectedYear, 2026);
        expect(state.selectedType, 'apunte');
        expect(state.subjects, isEmpty);
        expect(state.professors, isEmpty);
      },
    );

    test('selectCareer reinicia asignatura y profesor preservando universidad, año y tipo', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('subj-eda-uuid');
      notifier.selectProfessor('prof-mellado-uuid');
      notifier.selectYear(2025);
      notifier.selectType('certamen');

      // Cambiar carrera
      await notifier.selectCareer('ind-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'ind-uct-uuid');
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.selectedYear, 2025);
      expect(state.selectedType, 'certamen');
      expect(state.subjects, isNotEmpty);
      expect(state.professors, isEmpty);
    });

    test('selectSubject reinicia profesor preservando niveles superiores, año y tipo', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('subj-eda-uuid');
      notifier.selectProfessor('prof-mellado-uuid');

      // Cambiar asignatura
      await notifier.selectSubject('subj-calculo-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.selectedSubjectId, 'subj-calculo-uuid');
      expect(state.selectedProfessorId, isNull);
      expect(state.professors, isNotEmpty);
      expect(state.isLoadingProfessors, isFalse);
    });

    // -----------------------------------------------------------------------
    // Criterio: Respuesta vacía
    // -----------------------------------------------------------------------
    test('Respuesta vacía en carreras no causa excepciones y bloquea selección de carrera', () async {
      // Repositorio retorna lista vacía para carreras
      fakeRepo.onFetchCareers = (uniId) => [];

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uni-sin-carreras');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uni-sin-carreras');
      expect(state.careers, isEmpty);
      expect(state.isLoadingCareers, isFalse);
      expect(state.errorCareers, isNull);
      expect(state.canSelectCareer, isTrue); // Puede interactuar con el campo vacío
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

      await notifier.selectSubject('ramo-sin-profesores');
      state = container.read(academicHierarchyProvider);
      expect(state.professors, isEmpty);
      expect(state.errorProfessors, isNull);
    });

    // -----------------------------------------------------------------------
    // Criterio: Error de red y mensaje específico de nivel
    // -----------------------------------------------------------------------
    test('Error de red en carreras registra mensaje indicando nivel "carreras"', () async {
      fakeRepo.onFetchCareers = (uniId) {
        throw Exception('Fallo de conexión HTTP 500');
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.isLoadingCareers, isFalse);
      expect(state.errorCareers, isNotNull);
      expect(state.errorCareers, contains('carreras'));
      expect(state.errorCareers, contains('Fallo de conexión HTTP 500'));
      expect(state.careers, isEmpty);
      expect(state.canSelectCareer, isFalse);
    });

    test('Error de red en asignaturas registra mensaje indicando nivel "asignaturas"', () async {
      fakeRepo.onFetchSubjects = (careerId) {
        throw Exception('Timeout de red');
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.isLoadingSubjects, isFalse);
      expect(state.errorSubjects, isNotNull);
      expect(state.errorSubjects, contains('asignaturas'));
      expect(state.canSelectSubject, isFalse);
    });

    test('Error de red en profesores registra mensaje indicando nivel "profesores"', () async {
      fakeRepo.onFetchProfessors = (subjectId) {
        throw Exception('Servicio no disponible');
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');
      await notifier.selectSubject('subj-eda-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.isLoadingProfessors, isFalse);
      expect(state.errorProfessors, isNotNull);
      expect(state.errorProfessors, contains('profesores'));
      expect(state.canSelectProfessor, isFalse);
    });

    test('Error de red en universidades registra mensaje indicando nivel "universidades"', () async {
      fakeRepo.onFetchUniversities = () {
        throw Exception('Error 503');
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.loadUniversities();
      final state = container.read(academicHierarchyProvider);

      expect(state.isLoadingUniversities, isFalse);
      expect(state.errorUniversities, isNotNull);
      expect(state.errorUniversities, contains('universidades'));
    });

    // -----------------------------------------------------------------------
    // Criterio: El formulario no pierde campos no relacionados al reintentar
    // -----------------------------------------------------------------------
    test('retryCareers reintenta la carga y preserva universidad, año y tipo seleccionados', () async {
      bool fail = true;
      fakeRepo.onFetchCareers = (uniId) {
        if (fail) throw Exception('Fallo temporal');
        return CareerModel.mockList();
      };

      final notifier = container.read(academicHierarchyProvider.notifier);

      // El usuario elige universidad, año y tipo
      notifier.selectYear(2026);
      notifier.selectType('guia');
      await notifier.selectUniversity('uct-main-uuid');

      var state = container.read(academicHierarchyProvider);
      expect(state.errorCareers, isNotNull);
      expect(state.careers, isEmpty);
      expect(state.selectedYear, 2026);
      expect(state.selectedType, 'guia');
      expect(state.selectedUniversityId, 'uct-main-uuid');

      // Se soluciona el fallo de red y se reintenta
      fail = false;
      await notifier.retryCareers();

      state = container.read(academicHierarchyProvider);
      expect(state.errorCareers, isNull);
      expect(state.careers, isNotEmpty);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedYear, 2026);
      expect(state.selectedType, 'guia');
    });

    test('retrySubjects preserva universidad, carrera, año y tipo al reintentar', () async {
      bool fail = true;
      fakeRepo.onFetchSubjects = (careerId) {
        if (fail) throw Exception('Error en asignaturas');
        return SubjectModel.mockList();
      };

      final notifier = container.read(academicHierarchyProvider.notifier);
      notifier.selectYear(2024);
      notifier.selectType('taller');
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('inf-uct-uuid');

      var state = container.read(academicHierarchyProvider);
      expect(state.errorSubjects, isNotNull);
      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.selectedYear, 2024);
      expect(state.selectedType, 'taller');

      fail = false;
      await notifier.retrySubjects();

      state = container.read(academicHierarchyProvider);
      expect(state.errorSubjects, isNull);
      expect(state.subjects, isNotEmpty);
      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'inf-uct-uuid');
      expect(state.selectedYear, 2024);
      expect(state.selectedType, 'taller');
    });

    // -----------------------------------------------------------------------
    // Descarte de respuestas obsoletas
    // -----------------------------------------------------------------------
    test('Descarta respuestas de red obsoletas ante cambios rápidos de padre', () async {
      final slowCompleter = Completer<List<CareerModel>>();

      fakeRepo.onFetchCareers = (uniId) {
        if (uniId == 'uni-lenta') {
          return slowCompleter.future;
        }
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

      final notifier = container.read(academicHierarchyProvider.notifier);

      // Inicia petición lenta
      final p1 = notifier.selectUniversity('uni-lenta');
      // Inmediatamente cambia a uni rápida
      final p2 = notifier.selectUniversity('uni-rapida');

      await p2;
      var state = container.read(academicHierarchyProvider);
      expect(state.selectedUniversityId, 'uni-rapida');
      expect(state.careers.first.id, 'carrera-rapida');

      // Termina la petición lenta tardíamente
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

      // El estado NO debe haber sido pisado por la petición vieja
      state = container.read(academicHierarchyProvider);
      expect(state.selectedUniversityId, 'uni-rapida');
      expect(state.careers.first.id, 'carrera-rapida');
    });

    // -----------------------------------------------------------------------
    // toQueryParams y resets
    // -----------------------------------------------------------------------
    test('toQueryParams serializa los 6 filtros oficiales', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.selectUniversity('uct-uuid');
      await notifier.selectCareer('carr-uuid');
      await notifier.selectSubject('subj-uuid');
      notifier.selectProfessor('prof-uuid');
      notifier.selectYear(2026);
      notifier.selectType('guia');

      final params = container.read(academicHierarchyProvider).toQueryParams();
      expect(params['universityId'], 'uct-uuid');
      expect(params['careerId'], 'carr-uuid');
      expect(params['subjectId'], 'subj-uuid');
      expect(params['professorId'], 'prof-uuid');
      expect(params['year'], '2026');
      expect(params['type'], 'guia');
    });

    test('resetSelection limpia selección manteniendo universidades cargadas', () async {
      final notifier = container.read(academicHierarchyProvider.notifier);

      await notifier.loadUniversities();
      await notifier.selectUniversity('uct-main-uuid');
      await notifier.selectCareer('career-inf-uuid');
      notifier.selectYear(2025);
      notifier.selectType('apunte');

      expect(container.read(academicHierarchyProvider).hasActiveFilters, isTrue);

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
    });

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
    // Criterio: Aislamiento de carreras por universidad (#289)
    // Caso que generó el segundo CHANGES_REQUESTED de @cchelooo:
    // al elegir UFRO aparecían carreras de UCT (fallback incorrecto).
    // -----------------------------------------------------------------------
    test(
      'Elegir UFRO devuelve solo sus propias carreras, no las de UCT',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        // Primero seleccionamos UCT para asegurarnos de que el estado
        // previo no «contamina» la selección siguiente.
        await notifier.selectUniversity('uct-main-uuid');
        var state = container.read(academicHierarchyProvider);
        final uctCareerIds = state.careers.map((c) => c.id).toSet();
        expect(uctCareerIds, isNotEmpty);

        // Ahora seleccionamos UFRO
        await notifier.selectUniversity('ufro-main-uuid');
        state = container.read(academicHierarchyProvider);

        // Solo deben aparecer carreras de UFRO
        expect(state.careers, isNotEmpty,
            reason: 'UFRO debe tener carreras propias en el mock');
        expect(
          state.careers.every((c) => c.universityId == 'ufro-main-uuid'),
          isTrue,
          reason: 'Todas las carreras deben pertenecer a UFRO',
        );

        // Ninguna carrera de UCT debe aparecer
        final ufroCareerIds = state.careers.map((c) => c.id).toSet();
        expect(
          ufroCareerIds.intersection(uctCareerIds),
          isEmpty,
          reason: 'Las carreras de UCT no deben filtrarse con UFRO',
        );
      },
    );

    test(
      'Elegir universidad sin carreras en el mock devuelve lista vacía, no carreras de otra uni',
      () async {
        final notifier = container.read(academicHierarchyProvider.notifier);

        // 'desconocida-uuid' no tiene carreras en mockList
        await notifier.selectUniversity('desconocida-uuid');
        final state = container.read(academicHierarchyProvider);

        expect(
          state.careers,
          isEmpty,
          reason: 'No debe haber fallback a carreras de otras universidades',
        );
        expect(state.canSelectCareer, isTrue);
        expect(state.canSelectSubject, isFalse);
      },
    );
  });
}
