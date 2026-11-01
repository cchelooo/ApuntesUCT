import 'dart:typed_data';

import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_catalog_selectors_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_version_upload_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'upload_catalog_harness.dart';

/// Fija el tamaño lógico de la superficie (p. ej. 320×568 con dpr 2.0).
void _setSurface(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(w * 2.0, h * 2.0);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Monta el formulario de subida en tema oscuro con catálogo fake (sin red).
Future<void> _pumpUploadA11y(
  WidgetTester tester, {
  required double w,
  required double h,
  Future<MaterialPickedFile?> Function()? pickFile,
}) async {
  _setSurface(tester, w, h);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        uploadUniversitiesProvider.overrideWithValue(
          AsyncData(testUniversities()),
        ),
        for (final u in testUniversities())
          uploadCareersProvider(
            u.id,
          ).overrideWithValue(AsyncData(testCareersByUniversity()[u.id] ?? const [])),
        for (final c in testCareersByUniversity().values.expand((e) => e))
          uploadSubjectsProvider(
            c.id,
          ).overrideWithValue(AsyncData(testSubjectsByCareer()[c.id] ?? const [])),
        for (final s in testSubjectsByCareer().values.expand((e) => e))
          uploadProfessorsProvider(
            s.id,
          ).overrideWithValue(AsyncData(testProfessorsBySubject()[s.id] ?? const [])),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: MaterialUploadScreen(pickFile: pickFile),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monta la hoja de versión en tema oscuro con repositorio fake (sin red).
Future<void> _pumpSheetA11y(
  WidgetTester tester,
  _FakeVersionRepository fake, {
  required double w,
  required double h,
  Future<MaterialPickedFile?> Function()? pickFile,
}) async {
  _setSurface(tester, w, h);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: MaterialVersionUploadSheet(
            materialId: 'mat-1',
            currentVersionNumber: 2,
            pickFile:
                pickFile ??
                () async => MaterialPickedFile(
                  fileName: 'guia-v3.pdf',
                  sizeBytes: 3,
                  mimeType: 'application/pdf',
                  bytes: Uint8List.fromList(const [1, 2, 3]),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MaterialUploadScreen a11y móvil (#299)', () {
    testWidgets('320×568 oscuro + teclado + textos largos sin overflow', (
      tester,
    ) async {
      await _pumpUploadA11y(
        tester,
        w: 320,
        h: 568,
        pickFile: () async => MaterialPickedFile(
          fileName:
              'guia_de_estudio_muy_larga_para_probar_el_desbordamiento_v2.pdf',
          sizeBytes: 1048576,
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      );

      // Teclado abierto: el scroll debe absorber el inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();

      final selectButton = find.textContaining('Seleccionar archivo');
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();
      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(
        TextFormField,
        'Guía de ejercicios resueltos',
      );
      await tester.ensureVisible(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(
        titleField,
        'Guía de ejercicios resueltos con un título deliberadamente largo '
        'para comprobar que el campo no desborda en pantallas pequeñas',
      );

      final descField = find.widgetWithText(
        TextFormField,
        'Qué contiene y a quién le sirve',
      );
      await tester.ensureVisible(descField);
      await tester.pumpAndSettle();
      await tester.enterText(
        descField,
        'Descripción extensa: contiene resúmenes, ejercicios y pautas para '
        'todo el curso, útil para quienes preparan el examen final.',
      );

      // El botón de envío debe ser alcanzable con scroll y sin overflow.
      final submit = find.text('Subir material');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844 oscuro: foco y desplazamiento hasta el envío', (
      tester,
    ) async {
      await _pumpUploadA11y(tester, w: 390, h: 844);

      final titleField = find.widgetWithText(
        TextFormField,
        'Guía de ejercicios resueltos',
      );
      await tester.ensureVisible(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Guía de prueba');

      final yearField = find.widgetWithText(TextFormField, '2026');
      await tester.ensureVisible(yearField);
      await tester.pumpAndSettle();
      await tester.enterText(yearField, '2026');

      // Cada sección es alcanzable con scroll: el foco puede completar el
      // formulario de principio a fin.
      for (final label in ['Universidad', 'Carrera', 'Asignatura', 'Tipo']) {
        final field = find.text(label).first;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
      }
      final submit = find.text('Subir material');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      // Sin archivo ni clasificación: errores visibles como texto.
      expect(find.text('Selecciona un archivo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('botones y campos con etiquetas comprensibles', (tester) async {
      await _pumpUploadA11y(tester, w: 390, h: 844);
      final handle = tester.ensureSemantics();
      try {
        // Botones clave con etiqueta de semántica.
        expect(
          find.bySemanticsLabel('Subir material'),
          findsOneWidget,
          reason: 'El botón de envío debe anunciarse como "Subir material"',
        );
        expect(
          find.bySemanticsLabel(
            'Seleccionar archivo (PDF, Word, PPT · máx. 15 MB)',
          ),
          findsOneWidget,
          reason: 'El selector de archivo debe anunciar formato y límite',
        );
        // Etiquetas visibles de cada campo del formulario.
        for (final label in [
          'Título',
          'Descripción (opcional)',
          'Universidad',
          'Carrera',
          'Asignatura',
          'Profesor (opcional)',
          'Año',
          'Tipo',
        ]) {
          expect(
            find.text(label, findRichText: true),
            findsWidgets,
            reason: 'Falta etiqueta visible: $label',
          );
        }
        // Cada campo editable expone una etiqueta accesible no vacía.
        for (final field in find.byType(TextFormField).evaluate()) {
          final node = tester.getSemantics(find.byWidget(field.widget));
          expect(
            node.label.isNotEmpty,
            isTrue,
            reason: 'Campo sin etiqueta de semántica',
          );
        }
      } finally {
        handle.dispose();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('errores con texto o icono además del color', (tester) async {
      await _pumpUploadA11y(
        tester,
        w: 390,
        h: 844,
        pickFile: () async => MaterialPickedFile(
          fileName: 'gigante.pdf',
          sizeBytes: MaterialUploadValidation.maxFileSizeBytes + 1,
          mimeType: 'application/pdf',
        ),
      );

      final selectButton = find.textContaining('Seleccionar archivo');
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();
      await tester.tap(selectButton);
      await tester.pumpAndSettle();
      // Error de archivo: texto explícito + icono (no solo color).
      expect(
        find.text('El archivo supera el límite de 15 MB.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsWidgets);

      final submit = find.text('Subir material');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      // Errores de validación: mensajes de texto, no solo color.
      for (final msg in [
        'El título es obligatorio.',
        'El año es obligatorio.',
        'La universidad es obligatoria.',
        'El tipo es obligatorio.',
      ]) {
        expect(find.text(msg), findsWidgets, reason: 'Falta error: $msg');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('MaterialVersionUploadSheet a11y móvil (#299)', () {
    testWidgets('320×568 oscuro + teclado con nombre largo sin overflow', (
      tester,
    ) async {
      await _pumpSheetA11y(
        tester,
        _FakeVersionRepository(),
        w: 320,
        h: 568,
        pickFile: () async => MaterialPickedFile(
          fileName:
              'guia_de_estudio_muy_larga_para_probar_el_desbordamiento_v3.pdf',
          sizeBytes: 3,
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();

      final selectButton = find.textContaining('Seleccionar archivo');
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();
      await tester.tap(selectButton);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('desbordamiento'),
        findsOneWidget,
        reason: 'El nombre largo debe mostrarse con ellipsis, sin overflow',
      );

      final confirm = find.text('Confirmar subida de v3');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(confirm, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844 oscuro: semántica y confirmación alcanzable', (
      tester,
    ) async {
      await _pumpSheetA11y(tester, _FakeVersionRepository(), w: 390, h: 844);
      final handle = tester.ensureSemantics();
      try {
        expect(
          find.bySemanticsLabel(
            'Seleccionar archivo (PDF, Word, PPT · máx. 15 MB)',
          ),
          findsOneWidget,
        );
        final selectButton = find.textContaining('Seleccionar archivo');
        await tester.ensureVisible(selectButton);
        await tester.pumpAndSettle();
        await tester.tap(selectButton);
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Confirmar subida de v3'),
          findsOneWidget,
          reason: 'La confirmación debe anunciarse con su versión destino',
        );
        final confirm = find.text('Confirmar subida de v3');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
      } finally {
        handle.dispose();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('errores con texto o icono además del color', (tester) async {
      await _pumpSheetA11y(
        tester,
        _FakeVersionRepository(),
        w: 390,
        h: 844,
        pickFile: () async => MaterialPickedFile(
          fileName: 'virus.exe',
          sizeBytes: 1024,
          mimeType: 'application/octet-stream',
        ),
      );

      final selectButton = find.textContaining('Seleccionar archivo');
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();
      await tester.tap(selectButton);
      await tester.pumpAndSettle();
      // Error de formato: texto explícito + icono (no solo color).
      expect(find.textContaining('Formato no permitido'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeVersionRepository implements MaterialRepository {
  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async => MaterialVersion(
    id: 'ver-3',
    materialId: materialId,
    versionNumber: 3,
  );

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      throw UnimplementedError();

  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();
}
