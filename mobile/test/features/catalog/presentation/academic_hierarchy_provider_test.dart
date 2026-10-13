import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/models/models.dart';

void main() {
  group('AcademicHierarchyProvider Tests (Issue #281 & #282)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

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

    test('selectUniversity carga las carreras del padre y reinicia selecciones hijas', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.setUniversities(UniversityModel.mockList());

      // Seleccionar universidad UCT -> debe cargar carreras mock y desbloquear carrera
      notifier.selectUniversity('uct-main-uuid');
      var state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, isNull);
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);

      // Verifica que la cascada NO quede bloqueada: carreras cargadas
      expect(state.careers, isNotEmpty);
      expect(state.subjects, isEmpty);
      expect(state.professors, isEmpty);

      expect(state.canSelectCareer, isTrue);
      expect(state.canSelectSubject, isFalse);
      expect(state.canSelectProfessor, isFalse);

      // Seleccionar carrera
      notifier.selectCareer(state.careers.first.id);
      state = container.read(academicHierarchyProvider);
      expect(state.selectedCareerId, state.careers.first.id);
      expect(state.subjects, isNotEmpty);
      expect(state.canSelectSubject, isTrue);

      // Seleccionar asignatura
      notifier.selectSubject(state.subjects.first.id);
      state = container.read(academicHierarchyProvider);
      expect(state.selectedSubjectId, state.subjects.first.id);
      expect(state.professors, isNotEmpty);
      expect(state.canSelectProfessor, isTrue);

      // Si se cambia de universidad, se reinician las selecciones hijas y se cargan las carreras del nuevo padre
      notifier.selectUniversity('otra-uni-uuid');
      state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'otra-uni-uuid');
      expect(state.selectedCareerId, isNull);
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.careers, isNotEmpty);
      expect(state.subjects, isEmpty);
      expect(state.professors, isEmpty);
    });

    test('selectCareer carga asignaturas y reinicia niveles inferiores', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-main-uuid');
      notifier.selectCareer('inf-uct-uuid');
      notifier.selectSubject('subj-eda-uuid');
      notifier.selectProfessor('prof-mellado-uuid');

      // Cambiar carrera
      notifier.selectCareer('ind-uct-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedCareerId, 'ind-uct-uuid');
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);
      expect(state.subjects, isNotEmpty);
      expect(state.professors, isEmpty);

      expect(state.canSelectSubject, isTrue);
      expect(state.canSelectProfessor, isFalse);
    });

    test('selectSubject carga profesores y reinicia profesor previo', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-main-uuid');
      notifier.selectCareer('inf-uct-uuid');
      notifier.selectSubject('subj-eda-uuid');
      notifier.selectProfessor('prof-mellado-uuid');

      // Cambiar asignatura
      notifier.selectSubject('subj-calculo-uuid');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'subj-calculo-uuid');
      expect(state.selectedProfessorId, isNull);
      expect(state.professors, isNotEmpty);
      expect(state.canSelectProfessor, isTrue);
    });

    test('selectYear y selectType gestionan los filtros 5 y 6', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectYear(2026);
      expect(container.read(academicHierarchyProvider).selectedYear, 2026);
      expect(container.read(academicHierarchyProvider).isYearSelected, isTrue);

      notifier.selectType('certamen');
      expect(
        container.read(academicHierarchyProvider).selectedType,
        'certamen',
      );
      expect(container.read(academicHierarchyProvider).isTypeSelected, isTrue);
      expect(container.read(academicHierarchyProvider).activeFiltersCount, 2);

      notifier.selectYear(null);
      expect(container.read(academicHierarchyProvider).selectedYear, isNull);
      expect(container.read(academicHierarchyProvider).activeFiltersCount, 1);
    });

    test('toQueryParams serializa los 6 filtros oficiales', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-uuid');
      notifier.selectCareer('carr-uuid');
      notifier.selectSubject('subj-uuid');
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

    test(
      'resetSelection limpia selección manteniendo universidades cargadas',
      () {
        final notifier = container.read(academicHierarchyProvider.notifier);

        notifier.setUniversities(UniversityModel.mockList());
        notifier.selectUniversity('uct-main-uuid');
        notifier.selectCareer('career-inf-uuid');
        notifier.selectYear(2025);
        notifier.selectType('apunte');

        expect(
          container.read(academicHierarchyProvider).hasActiveFilters,
          isTrue,
        );

        notifier.resetSelection();
        final state = container.read(academicHierarchyProvider);

        expect(state.hasActiveFilters, isFalse);
        expect(state.selectedUniversityId, isNull);
        expect(state.selectedCareerId, isNull);
        expect(state.selectedYear, isNull);
        expect(state.selectedType, isNull);
        expect(state.universities, isNotEmpty);
      },
    );

    test('resetAll devuelve el estado a valores iniciales por defecto', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.loadMockHierarchy();
      notifier.selectUniversity('uct-main-uuid');

      notifier.resetAll();
      final state = container.read(academicHierarchyProvider);

      expect(state.universities, isEmpty);
      expect(state.selectedUniversityId, isNull);
    });
  });
}
