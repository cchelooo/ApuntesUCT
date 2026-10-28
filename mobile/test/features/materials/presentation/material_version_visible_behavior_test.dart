import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/widgets/app_primary_button.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_version_upload_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comportamiento visible faltante de #298 para nuevas versiones (#292):
/// archivo ausente, tamaño >15 MB y error 502 con reintento.
/// Lo ya cubierto (tipo no permitido, envío en progreso sin duplicar,
/// error 403 con reintento, confirmación vN creada) vive en
/// `material_version_upload_sheet_test.dart`.
void main() {
  group('MaterialVersionUploadSheet visible (#298)', () {
    testWidgets('sin archivo la confirmación está deshabilitada', (
      tester,
    ) async {
      final fake = _FakeVersionRepository();
      await _pumpSheet(tester, fake);

      // Sin elegir archivo no hay error todavía, pero confirmar está
      // deshabilitado: evita el envío vacío sin red.
      expect(find.textContaining('v3'), findsWidgets);
      final confirm = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Confirmar subida de v3'),
      );
      expect(confirm.onPressed, isNull);
      expect(fake.calls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rechaza archivo sobre 15 MB y bloquea confirmación', (
      tester,
    ) async {
      final fake = _FakeVersionRepository();
      await _pumpSheet(
        tester,
        fake,
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
      final confirm = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Confirmar subida de v3'),
      );
      expect(confirm.onPressed, isNull);
      expect(fake.calls, 0);
      expect(find.text('Versión v3 creada'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error del servidor permite reintentar y confirma', (
      tester,
    ) async {
      final fake = _FakeVersionRepository()..failNextWith502 = true;
      await _pumpSheet(tester, fake);

      await tester.tap(find.textContaining('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(find.text('Versión v3 creada'), findsNothing);
      // El archivo se conserva para reintentar.
      expect(find.text('guia-v3.pdf'), findsOneWidget);

      await tester.tap(find.text('Confirmar subida de v3'));
      await tester.pumpAndSettle();

      expect(fake.calls, 2);
      expect(find.text('Versión v3 creada'), findsOneWidget);
      expect(find.textContaining('no está disponible'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeVersionRepository implements MaterialRepository {
  var calls = 0;
  var failNextWith502 = false;

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    calls++;
    if (failNextWith502) {
      failNextWith502 = false;
      throw ApiException(
        message: 'Servicio no disponible.',
        statusCode: 502,
      );
    }
    final file = source as LocalMaterialFile;
    return MaterialVersion(
      id: 'ver-3',
      materialId: materialId,
      versionNumber: 3,
      originalFileName: file.fileName,
      mimeType: file.mimeType,
      fileSizeBytes: file.bytes.length,
      createdAt: DateTime.utc(2026, 10, 21),
    );
  }

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

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakeVersionRepository fake, {
  String materialId = 'mat-1',
  Future<MaterialPickedFile?> Function()? pickFile,
  int? currentVersionNumber = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: MaterialVersionUploadSheet(
            materialId: materialId,
            currentVersionNumber: currentVersionNumber,
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
