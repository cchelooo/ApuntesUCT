import 'dart:convert';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
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

void main() {
  const testMaterialId = 'mat_algebra_2026';
  final samplePdfBytes = utf8.encode('%PDF-1.4 test binary stream');

  final sampleDetailJson = {
    'id': testMaterialId,
    'title': 'Guía Vectores y Matrices',
    'description': 'Ejercicios resueltos.',
    'authorName': 'Carlos Gómez',
    'subjectName': 'Álgebra Lineal',
    'careerName': 'Ingeniería Civil Informática',
    'fileType': 'pdf',
    'academicYear': 2026,
    'materialType': 'guia',
    'status': 'aprobado',
    'downloadCount': 10,
    'rating': 5.0,
    'fileSizeBytes': samplePdfBytes.length,
    'tags': ['Álgebra'],
    'versions': [
      {
        'id': 'ver_01',
        'materialId': testMaterialId,
        'versionNumber': 1,
        'originalFileName': 'guia_vectores.pdf',
        'fileSizeBytes': samplePdfBytes.length,
        'mimeType': 'application/pdf',
      },
    ],
    'currentVersionId': 'ver_01',
  };

  group('Descarga y conservación de headers seguros (#291)', () {
    test(
      'DioMaterialRepository.download descarga bytes y no expone URLs de MinIO',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          // Criterio #291: La llamada se hace al Gateway, no a MinIO
          expect(options.path, contains('/materials/$testMaterialId/download'));
          expect(options.path, isNot(contains('minio')));
          expect(options.path, isNot(contains(':9000')));

          return ResponseBody(
            Stream.value(Uint8List.fromList(samplePdfBytes)),
            200,
            headers: {
              'content-type': ['application/pdf'],
              'content-disposition': [
                'attachment; filename="guia_vectores.pdf"',
              ],
            },
          );
        });

        final repository = DioMaterialRepository(ApiClient(customDio: dio));
        final download = await repository.download(
          testMaterialId,
          versionId: 'ver_01',
        );

        expect(download.fileName, 'guia_vectores.pdf');
        expect(download.mimeType, 'application/pdf');
        expect(download.bytes, samplePdfBytes);
      },
    );

    testWidgets(
      'Al presionar Descargar Material ejecuta la descarga sin exponer MinIO',
      (WidgetTester tester) async {
        final requestedUrls = <String>[];
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          requestedUrls.add(options.path);

          if (options.path.contains('/download')) {
            return ResponseBody(
              Stream.value(Uint8List.fromList(samplePdfBytes)),
              200,
              headers: {
                'content-type': ['application/pdf'],
                'content-disposition': [
                  'attachment; filename="guia_vectores.pdf"',
                ],
              },
            );
          }

          return ResponseBody.fromString(
            jsonEncode({'status': 'success', 'data': sampleDetailJson}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final apiClient = ApiClient(customDio: dio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [materialApiClientProvider.overrideWithValue(apiClient)],
            child: const MaterialApp(
              home: MaterialDetailScreen.byId(materialId: testMaterialId),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Buscamos y scrolleamos hasta el botón antes del tap
        final downloadButton = find.text('Descargar Material');
        expect(downloadButton, findsOneWidget);
        await tester.ensureVisible(downloadButton);
        await tester.pumpAndSettle();

        // Tap y procesamiento del SnackBar
        await tester.tap(downloadButton);
        await tester.pump();
        // Espera a que termine la llamada HTTP y se dibuje el SnackBar de éxito
        await tester.pump(const Duration(milliseconds: 100));

        // Verificar feedback exitoso
        expect(find.textContaining('Descarga completada'), findsOneWidget);

        // Terminar cualquier animación pendiente de los SnackBars
        await tester.pumpAndSettle();

        // Criterio de aceptación estricto #291: ninguna petición fue a MinIO ni expuso rutas privadas
        for (final url in requestedUrls) {
          expect(url.toLowerCase(), isNot(contains('minio')));
          expect(url, isNot(contains('9000')));
          expect(url, isNot(contains('storage')));
        }
      },
    );
  });
}
