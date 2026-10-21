import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Finder field<T>() => find.byType(DropdownButtonFormField<T>);

Future<void> select<T>(WidgetTester tester, String option) async {
  await tester.ensureVisible(field<T>());
  await tester.pumpAndSettle();
  await tester.tap(field<T>());
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> mount(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  // #285: la pantalla es ConsumerStatefulWidget (lee materialUploadProvider).
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: MaterialUploadScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Los niveles inferiores esperan a su padre', (tester) async {
    await mount(tester, 320);
    expect(
      tester
          .widget<DropdownButtonFormField<CareerModel>>(field<CareerModel>())
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<SubjectModel>>(field<SubjectModel>())
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<ProfessorModel?>>(
            field<ProfessorModel?>(),
          )
          .onChanged,
      isNull,
    );
    await select<UniversityModel>(tester, 'Universidad Católica de Temuco');
    await select<CareerModel>(tester, 'Ingeniería Civil en Informática');
    expect(
      tester
          .widget<DropdownButtonFormField<SubjectModel>>(field<SubjectModel>())
          .onChanged,
      isNotNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<ProfessorModel?>>(
            field<ProfessorModel?>(),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('Cambiar asignatura también limpia el profesor', (tester) async {
    await mount(tester, 320);
    await select<UniversityModel>(tester, 'Universidad Católica de Temuco');
    await select<CareerModel>(tester, 'Ingeniería Civil en Informática');
    await select<SubjectModel>(tester, 'Estructuras de Datos y Algoritmos');
    await select<ProfessorModel?>(tester, 'Nelson Mellado');
    await select<SubjectModel>(tester, 'Bases de Datos');
    expect(
      tester
          .state<FormFieldState<ProfessorModel?>>(field<ProfessorModel?>())
          .value,
      isNull,
    );
    expect(find.text('Nelson Mellado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'UFRO no ofrece carreras UCT y permite volver a UCT ($width px)',
      (tester) async {
        await mount(tester, width);
        await select<UniversityModel>(tester, 'Universidad Católica de Temuco');
        await select<CareerModel>(tester, 'Ingeniería Civil en Informática');
        await select<UniversityModel>(tester, 'Universidad de La Frontera');

        final careers = tester.widget<DropdownButtonFormField<CareerModel>>(
          field<CareerModel>(),
        );
        final menu = tester.widget<DropdownButton<CareerModel>>(
          find.descendant(
            of: field<CareerModel>(),
            matching: find.byType(DropdownButton<CareerModel>),
          ),
        );
        expect(menu.items, isEmpty);
        expect(careers.onChanged, isNull);
        expect(
          tester.state<FormFieldState<CareerModel>>(field<CareerModel>()).value,
          isNull,
        );
        expect(
          find.text('No hay carreras disponibles para esta universidad.'),
          findsOneWidget,
        );
        expect(find.text('Ingeniería Civil en Informática'), findsNothing);

        await select<UniversityModel>(tester, 'Universidad Católica de Temuco');
        await select<CareerModel>(tester, 'Medicina Veterinaria');
        expect(
          tester
              .state<FormFieldState<CareerModel>>(field<CareerModel>())
              .value!
              .id,
          'med-uct-uuid',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Cambiar carrera limpia asignatura y profesor visualmente ($width px)',
      (tester) async {
        await mount(tester, width);
        await select<UniversityModel>(tester, 'Universidad Católica de Temuco');
        await select<CareerModel>(tester, 'Ingeniería Civil en Informática');
        await select<SubjectModel>(tester, 'Estructuras de Datos y Algoritmos');
        await select<ProfessorModel?>(tester, 'Nelson Mellado');
        await select<CareerModel>(tester, 'Medicina Veterinaria');

        expect(
          tester
              .state<FormFieldState<SubjectModel>>(field<SubjectModel>())
              .value,
          isNull,
        );
        expect(
          tester
              .state<FormFieldState<ProfessorModel?>>(field<ProfessorModel?>())
              .value,
          isNull,
        );
        expect(find.text('Estructuras de Datos y Algoritmos'), findsNothing);
        expect(find.text('Nelson Mellado'), findsNothing);
        // El campo obligatorio también debe validar el estado limpio.
        expect(
          tester
              .state<FormFieldState<SubjectModel>>(field<SubjectModel>())
              .validate(),
          isFalse,
        );
        await tester.pumpAndSettle();
        expect(find.text('La asignatura es obligatoria.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
