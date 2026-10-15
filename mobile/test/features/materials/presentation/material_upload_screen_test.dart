import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaterialUploadValidation (#280)', () {
    test('acepta exactamente 15 MB y rechaza 15 MB + 1 byte', () {
      expect(
        MaterialUploadValidation.validatePickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: MaterialUploadValidation.maxFileSizeBytes,
        ),
        isNull,
      );
      expect(
        MaterialUploadValidation.validatePickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: MaterialUploadValidation.maxFileSizeBytes + 1,
        ),
        contains('15 MB'),
      );
    });

    test('solo acepta PDF, Word y PowerPoint', () {
      for (final ext in ['pdf', 'doc', 'docx', 'ppt', 'pptx']) {
        expect(
          MaterialUploadValidation.validatePickedFile(
            fileName: 'a.$ext',
            sizeBytes: 1024,
          ),
          isNull,
        );
      }
      expect(
        MaterialUploadValidation.validatePickedFile(
          fileName: 'a.exe',
          sizeBytes: 1024,
        ),
        contains('Formato'),
      );
      expect(
        MaterialUploadValidation.validatePickedFile(
          fileName: 'a.txt',
          sizeBytes: 1024,
        ),
        isNotNull,
      );
    });

    test('año YYYY y URL http/https', () {
      expect(MaterialUploadValidation.validateYear('2026'), isNull);
      expect(MaterialUploadValidation.validateYear('26'), isNotNull);
      expect(MaterialUploadValidation.validateYear('abcd'), isNotNull);
      expect(
        MaterialUploadValidation.validateExternalLink(
          'https://drive.google.com/x',
        ),
        isNull,
      );
      expect(
        MaterialUploadValidation.validateExternalLink('nota-valida'),
        isNotNull,
      );
      expect(
        MaterialUploadValidation.validateExternalLink('', required: false),
        isNull,
      );
    });

    test('título sin mínimo: solo exige no vacío (contrato @IsNotEmpty)',
        () {
      expect(MaterialUploadValidation.validateTitle('AB'), isNull);
      expect(MaterialUploadValidation.validateTitle('X'), isNull);
      expect(MaterialUploadValidation.validateTitle('  '), isNotNull);
      expect(MaterialUploadValidation.validateTitle(null), isNotNull);
    });

    test('coherencia tipo ↔ fuente', () {
      expect(
        MaterialUploadValidation.validateTypeAgainstSource(
          typeCode: 'LINK',
          isFileSource: true,
        ),
        isNotNull,
      );
      expect(
        MaterialUploadValidation.validateTypeAgainstSource(
          typeCode: 'DOCUMENT',
          isFileSource: false,
        ),
        isNotNull,
      );
      expect(
        MaterialUploadValidation.validateTypeAgainstSource(
          typeCode: 'LINK',
          isFileSource: false,
        ),
        isNull,
      );
      expect(
        MaterialUploadValidation.validateTypeAgainstSource(
          typeCode: 'DOCUMENT',
          isFileSource: true,
        ),
        isNull,
      );
    });
  });

  group('MaterialUploadScreen widget (#280)', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      Future<MaterialPickedFile?> Function()? pickFile,
      Size surface = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = surface;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MaterialUploadScreen(pickFile: pickFile),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra fuente, metadatos en orden oficial y botón',
        (tester) async {
      await pumpScreen(tester);

      for (final label in [
        'Fuente del material',
        'Título',
        'Descripción (opcional)',
        'Universidad',
        'Carrera',
        'Asignatura',
        'Profesor (opcional)',
        'Año',
        'Tipo',
        'Subir material',
      ]) {
        expect(find.text(label, findRichText: true), findsWidgets,
            reason: 'Falta: $label');
      }

      // Orden oficial: la posición vertical debe ser creciente.
      double topOf(String label) =>
          tester.getTopLeft(find.text(label).first).dy;
      final order = [
        'Universidad',
        'Carrera',
        'Asignatura',
        'Profesor (opcional)',
        'Año',
        'Tipo',
      ].map(topOf).toList();
      for (var i = 0; i < order.length - 1; i++) {
        expect(order[i], lessThan(order[i + 1]));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('envío vacío exige archivo, título, año y clasificación',
        (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text('Subir material'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir material'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un archivo.'), findsOneWidget);
      expect(find.text('El título es obligatorio.'), findsOneWidget);
      expect(find.text('El año es obligatorio.'), findsOneWidget);
      expect(find.text('La universidad es obligatoria.'), findsOneWidget);
      expect(find.text('La carrera es obligatoria.'), findsOneWidget);
      expect(find.text('La asignatura es obligatoria.'), findsOneWidget);
      expect(find.text('El tipo es obligatorio.'), findsOneWidget);
    });

    testWidgets('cambiar universidad limpia la carrera incompatible',
        (tester) async {
      await pumpScreen(tester);

      Future<void> selectOption({
        required String fieldLabel,
        required String option,
      }) async {
        final field = find.text(fieldLabel).first;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }

      await selectOption(
        fieldLabel: 'Universidad',
        option: 'Universidad Católica de Temuco',
      );
      await selectOption(
        fieldLabel: 'Carrera',
        option: 'Ingeniería Civil en Informática',
      );
      expect(
        find.text('Ingeniería Civil en Informática'),
        findsOneWidget,
      );

      // UCT → UFRO: la carrera UCT debe desaparecer del formulario,
      // aunque el fallback de mocks la siga ofreciendo en la lista.
      await selectOption(
        fieldLabel: 'Universidad Católica de Temuco',
        option: 'Universidad de La Frontera',
      );
      expect(
        find.text('Ingeniería Civil en Informática'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra nombre y tamaño del archivo elegido',
        (tester) async {
      await pumpScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: 1048576,
          mimeType: 'application/pdf',
        ),
      );

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();

      expect(find.text('apuntes.pdf'), findsOneWidget);
      expect(find.text('1.0 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rechaza archivo sobre 15 MB', (tester) async {
      await pumpScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'gigante.pdf',
          sizeBytes: MaterialUploadValidation.maxFileSizeBytes + 1,
          mimeType: 'application/pdf',
        ),
      );

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      expect(
        find.text('El archivo supera el límite de 15 MB.'),
        findsOneWidget,
      );
    });

    testWidgets('rechaza formato no permitido', (tester) async {
      await pumpScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'virus.exe',
          sizeBytes: 1024,
          mimeType: 'application/octet-stream',
        ),
      );
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Formato no permitido'), findsOneWidget);
    });

    testWidgets('fuente enlace exige URL válida', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Enlace'));
      await tester.pumpAndSettle();
      expect(find.text('Enlace externo'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'https://...').first,
        'nota-valida',
      );
      await tester.ensureVisible(find.text('Subir material'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir material'));
      await tester.pumpAndSettle();

      expect(find.textContaining('URL válida'), findsOneWidget);
    });

    testWidgets('es usable en 320 × 568 con teclado simulado',
        (tester) async {
      await pumpScreen(tester, surface: const Size(320, 568));

      // Simula teclado abierto: el scroll debe absorber el inset.
      tester.view.viewInsets = const FakeViewPadding(
        bottom: 300,
      );
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();

      final titleField = find.byType(TextFormField).first;
      await tester.ensureVisible(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Título de prueba');
      await tester.ensureVisible(find.text('Subir material'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
