import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/academic_filter_sheet.dart';

void main() {
  Widget buildTestWidget({
    VoidCallback? onApply,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
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
      ),
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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AcademicFilterSheet.show(context),
                    child: const Text('Abrir filtros'),
                  ),
                ),
              ),
            ),
          ),
        );

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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AcademicFilterSheet.show(context),
                    child: const Text('Abrir filtros'),
                  ),
                ),
              ),
            ),
          ),
        );

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
        notifier.selectUniversity('uct-main-uuid');
        notifier.selectYear(2026);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AcademicFilterSheet.show(
                      context,
                      onApply: () => applyTriggered = true,
                    ),
                    child: const Text('Abrir filtros'),
                  ),
                ),
              ),
            ),
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
}
