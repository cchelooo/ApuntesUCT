import 'dart:typed_data';

import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_route.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de backend con detalle mutable: `createVersion` crea la v3 y
/// actualiza el detalle, como haría el servicio real.
class _FakeBackend implements MaterialsRepository, MaterialRepository {
  MaterialDetail detail;
  var detailCalls = 0;
  var versionCalls = 0;

  _FakeBackend(this.detail);

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async {
    detailCalls++;
    return detail;
  }

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    versionCalls++;
    final file = source as LocalMaterialFile;
    final created = MaterialVersion(
      id: 'ver-3',
      materialId: materialId,
      versionNumber: 3,
      originalFileName: file.fileName,
      mimeType: file.mimeType,
      fileSizeBytes: file.bytes.length,
      createdAt: DateTime.utc(2026, 10, 27),
    );
    detail = MaterialDetail(
      summary: detail.summary,
      versions: [...detail.versions, created],
      currentVersionId: created.id,
    );
    return created;
  }

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  }) => throw UnimplementedError();

  @override
  Future<List<String>> getAvailableSubjects() => throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      throw UnimplementedError();

  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();
}

MaterialDetail _initialDetail() {
  MaterialVersion v(int n) => MaterialVersion(
    id: 'ver-$n',
    materialId: 'mat-1',
    versionNumber: n,
    originalFileName: 'guia-v$n.pdf',
    mimeType: 'application/pdf',
    fileSizeBytes: 10,
    createdAt: DateTime.utc(2026, 10, 20 + n),
  );
  return MaterialDetail(
    summary: const MaterialSummary(
      id: 'mat-1',
      title: 'Guía de Integrales',
      subjectName: 'Cálculo',
      materialType: 'DOCUMENT',
      status: 'APPROVED',
    ),
    versions: [v(1), v(2)],
    currentVersionId: 'ver-2',
  );
}

void main() {
  group('Detalle e historial tras subir versión (#292)', () {
    testWidgets(
      'entrar a la ruta, subir y ver la v3 sin salir y volver a entrar',
      (tester) async {
        final fake = _FakeBackend(_initialDetail());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              materialsRepositoryProvider.overrideWithValue(fake),
              dioMaterialRepositoryProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              home: MaterialDetailRoute(
                materialId: 'mat-1',
                versionPickFile: () async => MaterialPickedFile(
                  fileName: 'guia-v3.pdf',
                  sizeBytes: 3,
                  mimeType: 'application/pdf',
                  bytes: Uint8List.fromList(const [1, 2, 3]),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Estado inicial: v2 actual, sin rastro de v3.
        expect(fake.detailCalls, 1);
        expect(find.text('Versión actual: v2'), findsOneWidget);
        expect(find.text('v2'), findsOneWidget);
        expect(find.text('v3'), findsNothing);

        // Sube la v3 desde la hoja de la propia ruta.
        await tester.ensureVisible(find.text('Subir nueva versión'));
        await tester.tap(find.text('Subir nueva versión'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Seleccionar archivo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar subida de v3'));
        await tester.pumpAndSettle();

        expect(fake.versionCalls, 1);
        expect(find.text('Versión v3 creada'), findsOneWidget);

        // Cierra la hoja: el detalle y el historial ya muestran la v3,
        // sin salir de la ruta ni volver a entrar.
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();

        expect(fake.detailCalls, 2);
        expect(find.text('Versión actual: v3'), findsOneWidget);
        expect(find.text('v3'), findsOneWidget);
        expect(find.text('Versión v3 creada'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
