import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  MockHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Fake Notifier que maneja el ciclo de carga y bloqueo concurrente en memoria
/// sin realizar I/O de disco nativo (evitando que el Future quede suspendido en FakeAsync).
class FakeMaterialDownloadNotifier
    extends Notifier<AsyncValue<DownloadResult?>> {
  int downloadCalls = 0;

  @override
  AsyncValue<DownloadResult?> build() => const AsyncData(null);

  Future<DownloadResult?> download(
    String materialId, {
    String? versionId,
  }) async {
    if (state.isLoading) return null;

    downloadCalls++;
    state = const AsyncLoading();

    // Retardo controlado para validar el estado de carga y el bloqueo
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final result = DownloadResult(
      download: MaterialDownload(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'Guía.pdf',
        mimeType: 'application/pdf',
      ),
      savedPath: '/tmp/Guía.pdf',
    );

    state = AsyncData(result);
    return result;
  }
}

void main() {
  const testMaterialId = 'mat_algebra_2026';
  const testVersionId = 'ver_01';

  final testMaterialDetail = MaterialDetail(
    summary: const MaterialSummary(
      id: testMaterialId,
      title: 'Guía Oficial de Ejercicios',
      description: 'Ejercicios prácticos con soluciones paso a paso.',
      authorName: 'Carlos Gómez',
      academicYear: 2026,
      materialType: 'guia',
      status: 'aprobado',
      downloadCount: 15,
      rating: 5.0,
    ),
    downloadUrl: '/materials/$testMaterialId/download',
    fileSizeBytes: 2048,
    tags: const ['Álgebra'],
    viewCount: 40,
    currentVersionId: testVersionId,
    versions: const [
      MaterialVersion(
        id: testVersionId,
        materialId: testMaterialId,
        versionNumber: 1,
        originalFileName: 'Guía.pdf',
        fileSizeBytes: 2048,
        mimeType: 'application/pdf',
      ),
    ],
  );

  group('Descarga segura y RFC 5987 (#291)', () {
    test(
      'DioMaterialRepository.download decodifica RFC 5987 UTF-8 correctamente',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          expect(options.path, '/materials/$testMaterialId/download');
          expect(options.responseType, ResponseType.bytes);
          return ResponseBody(
            Stream.value(Uint8List.fromList([1, 2, 3, 4, 5])),
            200,
            headers: {
              'content-disposition': [
                "attachment; filename*=UTF-8''Gu%C3%ADa.pdf",
              ],
              'content-type': ['application/pdf'],
            },
          );
        });

        final apiClient = ApiClient(customDio: dio);
        final repository = DioMaterialRepository(apiClient);

        final result = await repository.download(
          testMaterialId,
          versionId: testVersionId,
        );

        expect(result.bytes.length, 5);
        expect(result.fileName, 'Guía.pdf');
        expect(result.mimeType, 'application/pdf');
      },
    );

    testWidgets(
      'Bloquea descargas simultáneas y muestra estado de carga',
      (WidgetTester tester) async {
        final fakeNotifier = FakeMaterialDownloadNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              materialDownloadProvider.overrideWith(() => fakeNotifier),
            ],
            child: MaterialApp(
              home: MaterialDetailScreen(detail: testMaterialDetail),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final buttonTextFinder = find.text('Descargar Material');
        expect(buttonTextFinder, findsOneWidget);

        // 1. Primer tap: dispara la descarga
        await tester.tap(buttonTextFinder);
        await tester.pump(); // Inicia estado de carga

        // Comprueba explícitamente el estado visual de carga
        expect(find.text('Descargando material...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // 2. Segundo tap concurrente: el botón está inactivo y el tap no genera nueva petición
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        // 3. Avanza el tiempo del delay simulado para completar la descarga
        await tester.pump(const Duration(milliseconds: 100));

        // 4. Anima la entrada del SnackBar
        await tester.pump(const Duration(milliseconds: 500));

        // Verificaciones
        expect(fakeNotifier.downloadCalls, 1);
        expect(find.text('Descarga completada: Guía.pdf'), findsOneWidget);
      },
    );
  });
}