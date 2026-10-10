import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/models/models.dart';

void main() {
  group('AcademicHierarchyProvider Tests (Issue #281)', () {
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

    test(
      'selectUniversity actualiza universidad y reinicia hijos en cascada',
      () {
        final notifier = container.read(academicHierarchyProvider.notifier);

        // Cargar datos mock iniciales
        notifier.setUniversities(UniversityModel.mockList());
        notifier.setCareers(CareerModel.mockList());
        notifier.setSubjects(SubjectModel.mockList());
        notifier.setProfessors(ProfessorModel.mockList());

        // Simular selección previa completa
        notifier.selectUniversity('uct-main-uuid');
        notifier.selectCareer('career-inf-uuid');
        notifier.selectSubject('subj-integra-iv-uuid');
        notifier.selectProfessor('prof-mellado-uuid');

        var state = container.read(academicHierarchyProvider);
        expect(state.selectedUniversityId, 'uct-main-uuid');
        expect(state.selectedCareerId, 'career-inf-uuid');
        expect(state.selectedSubjectId, 'subj-integra-iv-uuid');
        expect(state.selectedProfessorId, 'prof-mellado-uuid');
        expect(state.hasActiveFilters, isTrue);

        // Cambiar a otra universidad -> debe reiniciar carrera, asignatura y profesor
        notifier.selectUniversity('otra-uni-uuid');
        state = container.read(academicHierarchyProvider);

        expect(state.selectedUniversityId, 'otra-uni-uuid');
        expect(state.selectedCareerId, isNull);
        expect(state.selectedSubjectId, isNull);
        expect(state.selectedProfessorId, isNull);

        // Las listas dependientes se vacían esperando los datos del nuevo padre
        expect(state.careers, isEmpty);
        expect(state.subjects, isEmpty);
        expect(state.professors, isEmpty);

        expect(state.canSelectCareer, isTrue);
        expect(state.canSelectSubject, isFalse);
        expect(state.canSelectProfessor, isFalse);
      },
    );

    test('selectCareer reinicia asignatura y profesor', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-main-uuid');
      notifier.selectCareer('carrera-1');
      notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      // Cambiar carrera
      notifier.selectCareer('carrera-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'carrera-2');
      expect(state.selectedSubjectId, isNull);
      expect(state.selectedProfessorId, isNull);

      expect(state.canSelectSubject, isTrue);
      expect(state.canSelectProfessor, isFalse);
    });

    test('selectSubject reinicia profesor', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-main-uuid');
      notifier.selectCareer('carrera-1');
      notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      // Cambiar asignatura
      notifier.selectSubject('ramo-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedSubjectId, 'ramo-2');
      expect(state.selectedProfessorId, isNull);
      expect(state.canSelectProfessor, isTrue);
    });

    test('selectProfessor actualiza únicamente el profesor', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      notifier.selectUniversity('uct-main-uuid');
      notifier.selectCareer('carrera-1');
      notifier.selectSubject('ramo-1');
      notifier.selectProfessor('prof-1');

      notifier.selectProfessor('prof-2');
      final state = container.read(academicHierarchyProvider);

      expect(state.selectedUniversityId, 'uct-main-uuid');
      expect(state.selectedCareerId, 'carrera-1');
      expect(state.selectedSubjectId, 'ramo-1');
      expect(state.selectedProfessorId, 'prof-2');
    });

    test('toQueryParams serializa correctamente los parámetros no nulos', () {
      final notifier = container.read(academicHierarchyProvider.notifier);

      // Sin selección
      expect(
        container.read(academicHierarchyProvider).toQueryParams(),
        isEmpty,
      );

      // Selección parcial
      notifier.selectUniversity('uct-uuid');
      notifier.selectCareer('carr-uuid');
      expect(container.read(academicHierarchyProvider).toQueryParams(), {
        'universityId': 'uct-uuid',
        'careerId': 'carr-uuid',
      });

      // Selección completa
      notifier.selectSubject('subj-uuid');
      notifier.selectProfessor('prof-uuid');
      expect(container.read(academicHierarchyProvider).toQueryParams(), {
        'universityId': 'uct-uuid',
        'careerId': 'carr-uuid',
        'subjectId': 'subj-uuid',
        'professorId': 'prof-uuid',
      });
    });

    test(
      'resetSelection limpia selección manteniendo universidades cargadas',
      () {
        final notifier = container.read(academicHierarchyProvider.notifier);

        notifier.setUniversities(UniversityModel.mockList());
        notifier.selectUniversity('uct-main-uuid');
        notifier.selectCareer('career-inf-uuid');

        expect(
          container.read(academicHierarchyProvider).hasActiveFilters,
          isTrue,
        );

        notifier.resetSelection();
        final state = container.read(academicHierarchyProvider);

        expect(state.hasActiveFilters, isFalse);
        expect(state.selectedUniversityId, isNull);
        expect(state.selectedCareerId, isNull);
        expect(state.universities, isNotEmpty);
        expect(state.careers, isEmpty);
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

    test('Gestión de estados de carga y error por nivel', () {
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

    test('hasAcademicHierarchyFiltersProvider reacciona reactivamente a la selección', () {
      expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);

      container.read(academicHierarchyProvider.notifier).selectUniversity('u1');
      expect(container.read(hasAcademicHierarchyFiltersProvider), isTrue);

      container.read(academicHierarchyProvider.notifier).resetSelection();
      expect(container.read(hasAcademicHierarchyFiltersProvider), isFalse);
    });
  });
}
