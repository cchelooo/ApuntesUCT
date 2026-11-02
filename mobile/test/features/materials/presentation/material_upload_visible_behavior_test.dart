import 'dart:async';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_upload_response.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_test/flutter_test.dart';

import 'upload_catalog_harness.dart';

/// Comportamiento visible faltante de #298 para la creación (#280/#285):
/// envío en progreso sin duplicar + error del servidor con reintento.
/// Lo ya cubierto (campos, archivo ausente, >15MB, tipo, PENDING_REVIEW)
/// vive en `material_upload_screen_test.dart`.
void main() {
  group('MaterialUploadScreen visible (#298)', () {
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

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Guía de ejercicios resueltos'),
        'Guía de prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '2026'),
        '2026',
      );
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
    }

    testWidgets('envío en progreso muestra Subiendo y no duplica', (
      tester,
    ) async {
      final gate = Completer<MaterialDetail>();
      final fake = _GateUploadRepository(
        onUpload: (_) => gate.future,
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

      final submit = find.text('Subir material');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();

      // Estado visible de progreso: el botón pasa a carga y se deshabilita
      // (AppButton reemplaza la etiqueta por un progreso para no duplicar).
      await tester.pump();
      final uploading = tester.widget<AppPrimaryButton>(
        find.byType(AppPrimaryButton),
      );
      expect(uploading.label, 'Subiendo…');
      expect(uploading.isLoading, isTrue);
      expect(uploading.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Segundo toque mientras sube no dispara otra petición.
      await tester.tap(find.byType(AppPrimaryButton), warnIfMissed: false);
      await tester.pump();
      expect(fake.calls, 1);

      gate.complete(_createdDetail());
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      expect(find.text('¡Material recibido!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error del servidor permite reintentar y confirma', (
      tester,
    ) async {
      final fake = _RetryUploadRepository();
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

      Future<void> submit() async {
        final submit = find.text('Subir material');
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
      }

      await submit();

      // Error visible y formulario conservado (sin confirmación).
      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(find.text('¡Material recibido!'), findsNothing);
      expect(fake.calls, 1);

      // Reintento con el mismo formulario: ahora confirma PENDING_REVIEW.
      await submit();

      expect(fake.calls, 2);
      expect(find.text('¡Material recibido!'), findsOneWidget);
      expect(find.text('Estado: PENDING_REVIEW'), findsOneWidget);
      expect(find.textContaining('no está disponible'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

MaterialDetail _createdDetail() => materialDetailFromUploadResponse({
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

/// Fake que deja la petición en vuelo hasta completar [gate].
class _GateUploadRepository implements MaterialRepository {
  _GateUploadRepository({required this.onUpload});

  final Future<MaterialDetail> Function(UploadMaterialRequest request) onUpload;
  var calls = 0;

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) async {
    calls++;
    return onUpload(request);
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
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => throw UnimplementedError();
}

/// Fake que falla la primera subida (502) y confirma la segunda (201).
class _RetryUploadRepository implements MaterialRepository {
  var calls = 0;

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) async {
    calls++;
    if (calls == 1) {
      throw ApiException(
        message: 'Servicio no disponible.',
        statusCode: 502,
      );
    }
    return _createdDetail();
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
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => throw UnimplementedError();
}
