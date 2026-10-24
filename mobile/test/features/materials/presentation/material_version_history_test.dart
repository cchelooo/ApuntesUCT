import 'dart:typed_data';

import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_version_history.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MaterialVersion _version({
  required String id,
  required int number,
  required String date,
}) => MaterialVersion(
  id: id,
  materialId: 'mat-1',
  versionNumber: number,
  originalFileName: 'guia-v$number.pdf',
  mimeType: 'application/pdf',
  fileSizeBytes: 1000 * number,
  createdAt: DateTime.parse(date),
);

MaterialDetail _detail({
  required String type,
  List<MaterialVersion> versions = const [],
}) => MaterialDetail(
  summary: MaterialSummary(id: 'mat-1', title: 'Guía', materialType: type),
  versions: versions,
  currentVersionId: versions.isEmpty ? null : versions.first.id,
);

class FakeDownloadRepository implements MaterialRepository {
  String? requestedVersion;
  var calls = 0;

  @override
  Future<MaterialDownload> download(
    String materialId, {
    String? versionId,
  }) async {
    calls++;
    requestedVersion = versionId;
    return MaterialDownload(
      fileName: 'guia.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
  }

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
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => throw UnimplementedError();
}

class _FakeFiles implements MaterialFileHandler {
  String? savedPath;
  String? openedPath;
  String? openedMime;

  @override
  Future<String> save(MaterialDownload download) async {
    savedPath = '/cache/guia.pdf';
    return savedPath!;
  }

  @override
  Future<void> open(String path, String mimeType) async {
    openedPath = path;
    openedMime = mimeType;
  }
}

void main() {
  group('MaterialVersionHistory widget (#293)', () {
    testWidgets('muestra actual destacada e historial con número y fecha', (
      tester,
    ) async {
      final versions = [
        _version(id: 'v3', number: 3, date: '2026-10-20T10:00:00.000Z'),
        _version(id: 'v2', number: 2, date: '2026-10-10T10:00:00.000Z'),
        _version(id: 'v1', number: 1, date: '2026-09-01T10:00:00.000Z'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionHistory(
                materialId: 'mat-1',
                detail: _detail(type: 'DOCUMENT', versions: versions),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de versiones'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
      expect(find.textContaining('20/10/2026'), findsOneWidget);
      expect(find.textContaining('01/09/2026'), findsOneWidget);
      // Tres filas descargables (actual + 2 anteriores).
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('enlace externo: nota sin acciones falsas', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionHistory(
                materialId: 'mat-1',
                detail: _detail(type: 'LINK'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('enlace externo'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(find.text('Actual'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin versiones: estado vacío explícito', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionHistory(
                materialId: 'mat-1',
                detail: _detail(type: 'DOCUMENT'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aún no hay versiones registradas para este material.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('descargar versión anterior usa su versionId', (tester) async {
      final downloads = FakeDownloadRepository();
      final files = _FakeFiles();
      final versions = [
        _version(id: 'v2', number: 2, date: '2026-10-20T10:00:00.000Z'),
        _version(id: 'v1', number: 1, date: '2026-09-01T10:00:00.000Z'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioMaterialRepositoryProvider.overrideWithValue(downloads),
            materialFileHandlerProvider.overrideWithValue(files),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MaterialVersionHistory(
                materialId: 'mat-1',
                detail: _detail(type: 'DOCUMENT', versions: versions),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Segunda fila = v1 (anterior): su botón es el segundo icono.
      final buttons = find.byIcon(Icons.download_outlined);
      expect(buttons, findsNWidgets(2));
      await tester.tap(buttons.at(1));
      await tester.pumpAndSettle();

      expect(downloads.calls, 1);
      expect(downloads.requestedVersion, 'v1');
      expect(find.textContaining('Descarga completada'), findsOneWidget);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(files.openedPath, '/cache/guia.pdf');
      expect(files.openedMime, 'application/pdf');
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalle oculta subida en LINK y la muestra en archivo', (
      tester,
    ) async {
      Future<void> pumpDetail(MaterialDetail detail) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: MaterialDetailScreen(detail: detail)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpDetail(_detail(type: 'LINK'));
      expect(find.text('Subir nueva versión'), findsNothing);
      expect(find.textContaining('enlace externo'), findsOneWidget);

      await pumpDetail(_detail(type: 'DOCUMENT'));
      expect(find.text('Subir nueva versión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
