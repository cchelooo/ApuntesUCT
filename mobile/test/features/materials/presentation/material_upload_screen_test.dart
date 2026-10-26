import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_upload_response.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'upload_catalog_harness.dart';

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

    test('título sin mínimo: solo exige no vacío (contrato @IsNotEmpty)', () {
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
    Finder fieldByHint(String hint) => find.widgetWithText(TextFormField, hint);

    Future<void> selectOption(
      WidgetTester tester, {
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

    testWidgets('muestra fuente, metadatos en orden oficial y botón', (
      tester,
    ) async {
      await pumpUploadScreen(tester);

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
        expect(
          find.text(label, findRichText: true),
          findsWidgets,
          reason: 'Falta: $label',
        );
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

    testWidgets('envío vacío exige archivo, título, año y clasificación', (
      tester,
    ) async {
      await pumpUploadScreen(tester);

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

    testWidgets('cambiar universidad limpia la carrera incompatible', (
      tester,
    ) async {
      await pumpUploadScreen(tester);

      await selectOption(
        tester,
        fieldLabel: 'Universidad',
        option: 'Universidad Católica de Temuco',
      );
      await selectOption(
        tester,
        fieldLabel: 'Carrera',
        option: 'Ingeniería Civil en Informática',
      );
      expect(find.text('Ingeniería Civil en Informática'), findsOneWidget);

      // UCT → UFRO: la carrera UCT debe desaparecer del formulario,
      // y tampoco debe ofrecerse de nuevo para la universidad elegida.
      await selectOption(
        tester,
        fieldLabel: 'Universidad Católica de Temuco',
        option: 'Universidad de La Frontera',
      );
      expect(find.text('Ingeniería Civil en Informática'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra nombre y tamaño del archivo elegido', (tester) async {
      await pumpUploadScreen(
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
      await pumpUploadScreen(
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
      await pumpUploadScreen(
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
      await pumpUploadScreen(tester);

      await tester.tap(find.text('Enlace'));
      await tester.pumpAndSettle();
      expect(find.text('Enlace externo'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'https://...').first,
        'nota-valida',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Subir material'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir material'));
      await tester.pumpAndSettle();

      expect(find.textContaining('URL válida'), findsOneWidget);
    });

    testWidgets('es usable en 320 × 568 con teclado simulado', (tester) async {
      await pumpUploadScreen(tester, surface: const Size(320, 568));

      // Simula teclado abierto: el scroll debe absorber el inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
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

    /// Completa el formulario válido y lo envía (requiere pickFile con
    /// bytes y repositorio fake ya configurados en pumpScreen).
    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      expect(find.text('apuntes.pdf'), findsOneWidget);

      final titleField = fieldByHint('Guía de ejercicios resueltos');
      await tester.ensureVisible(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Guía de prueba');

      final yearField = fieldByHint('2026');
      await tester.ensureVisible(yearField);
      await tester.pumpAndSettle();
      await tester.enterText(yearField, '2026');

      await selectOption(
        tester,
        fieldLabel: 'Universidad',
        option: 'Universidad Católica de Temuco',
      );
      await selectOption(
        tester,
        fieldLabel: 'Carrera',
        option: 'Ingeniería Civil en Informática',
      );
      await selectOption(
        tester,
        fieldLabel: 'Asignatura',
        option: 'Bases de Datos',
      );
      await selectOption(tester, fieldLabel: 'Tipo', option: 'Documento');

      final submit = find.text('Subir material');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    Finder noPublicado() => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').toLowerCase().contains('ublicad'),
    );

    testWidgets('envío válido confirma recepción con PENDING_REVIEW', (
      tester,
    ) async {
      final fake = _FakeUploadRepository();
      await pumpUploadScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: 3,
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
        uploadRepository: fake,
      );
      await fillValidForm(tester);

      // 1. Se confirma la recepción con el detalle devuelto.
      expect(find.text('¡Material recibido!'), findsOneWidget);
      expect(find.text('Guía de prueba'), findsOneWidget);
      expect(find.text('Documento'), findsOneWidget);
      // H1: el nombre viene del request enviado, no del fallback 'General'.
      expect(find.text('Bases de Datos'), findsOneWidget);

      // 2. PENDING_REVIEW explícito, sin afirmar publicación.
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Estado: PENDING_REVIEW'), findsOneWidget);
      expect(noPublicado(), findsNothing);

      // 3. Acciones: volver al inicio o subir otro.
      expect(find.text('Volver al inicio'), findsOneWidget);
      expect(find.text('Subir otro material'), findsOneWidget);

      // 4. El formulario quedó limpio tras el éxito confirmado: ya no
      // se muestra (ni siquiera vacío) y dio paso a la confirmación.
      expect(find.text('Comparte tus apuntes'), findsNothing);
      expect(find.text('Subir material'), findsNothing);
      expect(find.text('Fuente del material'), findsNothing);

      final captured = fake.lastRequest;
      expect(captured, isNotNull);
      expect(captured!.title, 'Guía de prueba');
      expect(captured.year, 2026);
      expect(captured.type, 'DOCUMENT');
      // Regresión #287: las referencias son UUID reales de Catalog, no los
      // ficticios anteriores (`subj-eda-uuid` → 400 del backend).
      expect(captured.subject.id, testBdId);
      expect(captured.career.id, testIciId);
      expect(isCatalogUuid(captured.subject.id), isTrue);
      expect(isCatalogUuid(captured.career.id), isTrue);
      expect(isCatalogUuid(captured.university.id), isTrue);
      expect(captured.professor, isNull);
      expect(captured.backupLink, isNull);
      final source = captured.source;
      expect(source, isA<LocalMaterialFile>());
      source as LocalMaterialFile;
      expect(source.fileName, 'apuntes.pdf');
      expect(source.mimeType, 'application/pdf');
      expect(source.bytes, [1, 2, 3]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Subir otro material vuelve al formulario vacío', (
      tester,
    ) async {
      final fake = _FakeUploadRepository();
      await pumpUploadScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: 3,
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
        uploadRepository: fake,
      );
      await fillValidForm(tester);
      expect(find.text('¡Material recibido!'), findsOneWidget);

      await tester.tap(find.text('Subir otro material'));
      await tester.pumpAndSettle();

      expect(find.text('Comparte tus apuntes'), findsOneWidget);
      expect(find.text('¡Material recibido!'), findsNothing);
      // El formulario reaparece vacío.
      final titleField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(titleField.controller?.text, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error de subida conserva los datos sin limpiar', (
      tester,
    ) async {
      final fake = _FakeUploadRepository()
        ..failure = ApiException(
          message: 'Servicio no disponible.',
          statusCode: 502,
        );
      await pumpUploadScreen(
        tester,
        pickFile: () async => MaterialPickedFile(
          fileName: 'apuntes.pdf',
          sizeBytes: 3,
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
        uploadRepository: fake,
      );
      await fillValidForm(tester);

      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(find.text('¡Material recibido!'), findsNothing);

      // El formulario conserva lo digitado: solo se limpia tras éxito.
      final titleField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(titleField.controller?.text, 'Guía de prueba');
      expect(find.text('Comparte tus apuntes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error de catálogo deshabilita y reintenta', (tester) async {
      final fake = _FlakyCatalogRepository()..failUniversities = true;
      tester.view.devicePixelRatio = 1;
      // Superficie alta para que el botón Reintentar esté visible sin scroll.
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogSelectorRepositoryProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: MaterialUploadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Sin universidades, el selector queda deshabilitado con reintento.
      expect(
        find.text('No se pudieron cargar las universidades.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<CareerModel>>(
              find.byType(DropdownButtonFormField<CareerModel>),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('Universidad').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Universidad Católica de Temuco'), findsNothing);

      // Reintentar recarga el listado y habilita el selector.
      fake.failUniversities = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron cargar las universidades.'),
        findsNothing,
      );
      await tester.tap(find.text('Universidad').first);
      await tester.pumpAndSettle();
      expect(find.text('Universidad Católica de Temuco'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error de carreras deshabilita y reintenta', (tester) async {
      final fake = _FlakyCatalogRepository()..failCareerIds = {testUctId};
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogSelectorRepositoryProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: MaterialUploadScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final universityLabel = find.text('Universidad').first;
      await tester.ensureVisible(universityLabel);
      await tester.pumpAndSettle();
      await tester.tap(universityLabel);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Universidad Católica de Temuco').last);
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar las carreras.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<CareerModel>>(
              find.byType(DropdownButtonFormField<CareerModel>),
            )
            .onChanged,
        isNull,
      );

      fake.failCareerIds.clear();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar las carreras.'), findsNothing);

      final careerLabel = find.text('Carrera').first;
      await tester.ensureVisible(careerLabel);
      await tester.pumpAndSettle();
      await tester.tap(careerLabel);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingeniería Civil en Informática').last);
      await tester.pumpAndSettle();
      expect(find.text('Ingeniería Civil en Informática'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Volver al inicio navega a la ruta home', (tester) async {
      final fake = _FakeUploadRepository();
      final router = GoRouter(
        initialLocation: '/materials/upload',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Text('home-test'),
          ),
          GoRoute(
            path: '/materials/upload',
            builder: (context, state) => MaterialUploadScreen(
              pickFile: () async => MaterialPickedFile(
                fileName: 'apuntes.pdf',
                sizeBytes: 3,
                mimeType: 'application/pdf',
                bytes: Uint8List.fromList(const [1, 2, 3]),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpUploadScreen(tester, uploadRepository: fake, router: router);

      await fillValidForm(tester);
      expect(find.text('¡Material recibido!'), findsOneWidget);

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      expect(find.text('home-test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Catalog que falla la primera carga de universidades y luego responde
/// con los fixtures de UUID reales (#287).
class _FlakyCatalogRepository extends CatalogSelectorRepository {
  _FlakyCatalogRepository() : super(ApiClient(customDio: Dio()));

  var failUniversities = false;

  @override
  Future<List<UniversityModel>> listUniversities() async {
    if (failUniversities) {
      throw DioException(requestOptions: RequestOptions());
    }
    return testUniversities();
  }

  var failCareerIds = <String>{};

  @override
  Future<List<CareerModel>> listCareers({String? universityId}) async {
    if (universityId != null && failCareerIds.contains(universityId)) {
      throw DioException(requestOptions: RequestOptions());
    }
    return testCareersByUniversity()[universityId] ?? const [];
  }

  @override
  Future<List<SubjectModel>> listSubjects({String? careerId}) async =>
      testSubjectsByCareer()[careerId] ?? const [];

  @override
  Future<List<ProfessorModel>> listProfessors({String? subjectId}) async =>
      testProfessorsBySubject()[subjectId] ?? const [];
}

/// Fake del repositorio real: captura el request sin red (#285).
class _FakeUploadRepository implements MaterialRepository {
  UploadMaterialRequest? lastRequest;

  /// Si se define, upload lanza este error en vez de responder 201.
  Object? failure;

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) async {
    lastRequest = request;
    if (failure != null) throw failure!;
    // Usa el parser real del 201 (H6): si el adaptador falla, el test lo
    // detecta en vez de ocultar el bug con un objeto construido a mano.
    return materialDetailFromUploadResponse({
      'id': 'mat-900',
      'title': 'Guía de prueba',
      'description': 'Subida de prueba.',
      'year': '2026',
      'type': 'DOCUMENT',
      'status': 'PENDING_REVIEW',
      'subjectId': testBdId,
      'careerId': testIciId,
      'professorId': null,
      'universityId': testUctId,
      'fileUrl': null,
      'fileSize': 3,
      'mimeType': 'application/pdf',
      'externalLink': null,
      'createdAt': '2026-10-05T14:00:00.000Z',
    });
  }

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();

  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source,
  ) => throw UnimplementedError();
}
