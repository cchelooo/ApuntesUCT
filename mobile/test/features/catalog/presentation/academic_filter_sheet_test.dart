import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/academic_filter_sheet.dart';
import 'package:apuntesuct_mobile/models/models.dart';

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
    final all = CareerModel.mockList();
    final matching = all.where((c) => c.universityId == universityId).toList();
    return matching.isNotEmpty ? matching : all;
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
  Widget buildTestWidget({
    VoidCallback? onApply,
    List<dynamic> overrides = const [],
    ProviderContainer? container,
  }) {
    final app = MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  AcademicFilterSheet.show(context, onApply: onApply),
              child: const Text('Abrir filtros'),
            );
          },
        ),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: app,
      );
    }

    return ProviderScope(
      overrides: overrides.cast(),
      child: app,
    );
  }

  group('AcademicFilterSheet Widget Tests (Issue #282 - 6 Filtros)', () {
    testWidgets('Renderiza el modal con los 6 filtros en orden oficial', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Abrir el modal
      await tester.tap(find.text('Abrir filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Filtros del Catálogo'), findsOneWidget);
      // 1. Universidad
      expect(
        find.byKey(const Key('filter_university_dropdown')),
        findsOneWidget,
      );
      // 2. Carrera
      expect(find.byKey(const Key('filter_career_dropdown')), findsOneWidget);
      // 3. Asignatura
      expect(find.byKey(const Key('filter_subject_dropdown')), findsOneWidget);
      // 4. Profesor
      expect(
        find.byKey(const Key('filter_professor_dropdown')),
        findsOneWidget,
      );
      // 5. Año
      expect(find.byKey(const Key('filter_year_dropdown')), findsOneWidget);
      // 6. Tipo
      expect(find.byKey(const Key('filter_type_dropdown')), findsOneWidget);

      expect(find.byKey(const Key('filter_apply_button')), findsOneWidget);
      expect(find.byKey(const Key('filter_close_button')), findsOneWidget);
    });

    testWidgets(
      'Mantiene deshabilitados los niveles hijos si no hay padre seleccionado',
      (tester) async {
        final container = ProviderContainer();
        container.read(academicHierarchyProvider.notifier).resetAll();

        await tester.pumpWidget(buildTestWidget(container: container));

        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        expect(find.text('Selecciona una universidad primero'), findsOneWidget);
        expect(find.text('Selecciona una carrera primero'), findsOneWidget);
        expect(find.text('Selecciona una asignatura primero'), findsOneWidget);
      },
    );

    testWidgets(
      'Al seleccionar universidad carga carreras sin bloquear la cascada',
      (tester) async {
        final container = ProviderContainer();

        await tester.pumpWidget(buildTestWidget(container: container));

        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        // Seleccionar universidad en el dropdown
        await tester.tap(find.byKey(const Key('filter_university_dropdown')));
        await tester.pumpAndSettle();

        // Elegir UCT
        await tester.tap(find.text('Universidad Católica de Temuco').last);
        await tester.pumpAndSettle();

        // Carrera ya no debe tener el texto de bloqueo y debe tener opciones disponibles
        expect(find.text('Selecciona una universidad primero'), findsNothing);
        expect(find.text('Seleccionar carrera...'), findsOneWidget);

        // Abrir dropdown de Carrera
        await tester.tap(find.byKey(const Key('filter_career_dropdown')));
        await tester.pumpAndSettle();

        // Debe mostrar carreras mock sin estar bloqueado
        expect(
          find.text('Ingeniería Civil en Informática').last,
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Botón Limpiar restablece la selección y botón Aplicar dispara callback',
      (tester) async {
        bool applyTriggered = false;
        final container = ProviderContainer();
        final notifier = container.read(academicHierarchyProvider.notifier);
        notifier.loadMockHierarchy();
        await notifier.selectUniversity('uct-main-uuid');
        notifier.selectYear(2026);

        await tester.pumpWidget(
          buildTestWidget(
            container: container,
            onApply: () => applyTriggered = true,
          ),
        );

        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        // El botón Limpiar debe estar presente
        expect(find.byKey(const Key('filter_reset_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('filter_reset_button')));
        await tester.pumpAndSettle();

        expect(
          container.read(academicHierarchyProvider).hasActiveFilters,
          isFalse,
        );

        // Tocar Aplicar
        await tester.ensureVisible(find.byKey(const Key('filter_apply_button')));
        await tester.tap(find.byKey(const Key('filter_apply_button')));
        await tester.pumpAndSettle();

        expect(applyTriggered, isTrue);
        // El modal debe haberse cerrado
        expect(find.byType(AcademicFilterSheet), findsNothing);
      },
    );
  });

  group('AcademicFilterSheet - Validación y Estados Parciales (Issue #289)', () {
    late FakeAcademicHierarchyRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAcademicHierarchyRepository();
    });

    testWidgets('Reseteo de filtros hijos en UI al cambiar universidad padre', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          academicHierarchyRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await tester.pumpWidget(buildTestWidget(container: container));
      await tester.tap(find.text('Abrir filtros'));
      await tester.pumpAndSettle();

      // 1. Seleccionar universidad
      await tester.tap(find.byKey(const Key('filter_university_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universidad Católica de Temuco').last);
      await tester.pumpAndSettle();

      // 2. Seleccionar carrera
      await tester.tap(find.byKey(const Key('filter_career_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingeniería Civil en Informática').last);
      await tester.pumpAndSettle();

      expect(
        container.read(academicHierarchyProvider).selectedCareerId,
        isNotNull,
      );

      // 3. Cambiar de universidad a Universidad de La Frontera
      await tester.tap(find.byKey(const Key('filter_university_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universidad de La Frontera').last);
      await tester.pumpAndSettle();

      // El dropdown de carrera debe haberse reseteado (selectedCareerId == null)
      expect(
        container.read(academicHierarchyProvider).selectedCareerId,
        isNull,
      );
      expect(find.text('Seleccionar carrera...'), findsOneWidget);
    });

    testWidgets(
      'Respuesta vacía en carreras muestra hint "No hay carreras disponibles"',
      (tester) async {
        fakeRepo.onFetchCareers = (uniId) => [];

        final container = ProviderContainer(
          overrides: [
            academicHierarchyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );

        await tester.pumpWidget(buildTestWidget(container: container));
        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        // Seleccionar universidad
        await tester.tap(find.byKey(const Key('filter_university_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Universidad Católica de Temuco').last);
        await tester.pumpAndSettle();

        // El dropdown de carrera debe indicar que no hay carreras disponibles
        expect(find.text('No hay carreras disponibles'), findsOneWidget);
      },
    );

    testWidgets(
      'Error de red muestra mensaje indicando el nivel y botón de reintento',
      (tester) async {
        fakeRepo.onFetchCareers = (uniId) {
          throw Exception('Error de conexión con el gateway');
        };

        final container = ProviderContainer(
          overrides: [
            academicHierarchyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );

        await tester.pumpWidget(buildTestWidget(container: container));
        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        // Seleccionar universidad para disparar carga de carreras con error
        await tester.tap(find.byKey(const Key('filter_university_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Universidad Católica de Temuco').last);
        await tester.pumpAndSettle();

        // Debe mostrarse el mensaje que indica qué nivel falló
        expect(
          find.textContaining('No se pudieron cargar las carreras'),
          findsOneWidget,
        );
        // Debe mostrarse el botón Reintentar
        expect(find.byKey(const Key('retry_career_button')), findsOneWidget);
      },
    );

    testWidgets(
      'El formulario no pierde campos no relacionados (Año y Tipo) al reintentar',
      (tester) async {
        bool failCareers = true;
        fakeRepo.onFetchCareers = (uniId) {
          if (failCareers) throw Exception('Fallo de red');
          return CareerModel.mockList();
        };

        final container = ProviderContainer(
          overrides: [
            academicHierarchyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );

        await tester.pumpWidget(buildTestWidget(container: container));
        await tester.tap(find.text('Abrir filtros'));
        await tester.pumpAndSettle();

        // 1. Configurar campos no relacionados: Año y Tipo
        await tester.ensureVisible(find.byKey(const Key('filter_year_dropdown')));
        await tester.tap(find.byKey(const Key('filter_year_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('filter_type_dropdown')));
        await tester.tap(find.byKey(const Key('filter_type_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('APUNTE').last);
        await tester.pumpAndSettle();

        // Verificar que los campos no relacionados quedaron seleccionados
        expect(container.read(academicHierarchyProvider).selectedYear, 2026);
        expect(container.read(academicHierarchyProvider).selectedType, 'apunte');

        // 2. Seleccionar universidad (provoca fallo de red en carreras)
        await tester.ensureVisible(
          find.byKey(const Key('filter_university_dropdown')),
        );
        await tester.tap(find.byKey(const Key('filter_university_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Universidad Católica de Temuco').last);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No se pudieron cargar las carreras'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('retry_career_button')), findsOneWidget);

        // 3. Recuperar conexión y presionar Reintentar
        failCareers = false;
        await tester.tap(find.byKey(const Key('retry_career_button')));
        await tester.pumpAndSettle();

        // El error ya no debe mostrarse y las carreras están cargadas
        expect(
          find.textContaining('No se pudieron cargar las carreras'),
          findsNothing,
        );
        expect(
          container.read(academicHierarchyProvider).careers,
          isNotEmpty,
        );

        // Y lo más importante: los campos no relacionados Año y Tipo se mantuvieron intactos
        expect(container.read(academicHierarchyProvider).selectedYear, 2026);
        expect(container.read(academicHierarchyProvider).selectedType, 'apunte');
        expect(
          container.read(academicHierarchyProvider).selectedUniversityId,
          'uct-main-uuid',
        );
      },
    );
  });
}
