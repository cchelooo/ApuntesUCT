import 'dart:convert';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
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
  const testMaterialId = 'mat_12345';

  final sampleDetailJson = {
    'id': testMaterialId,
    'title': 'Certamen 2 Resuelto - Álgebra',
    'description': 'Pauta oficial de corrección y desarrollo paso a paso.',
    'authorName': 'Valentina Soto',
    'subjectId': '44444444-4444-4444-8444-444444444444',
    'subjectName': 'Álgebra Lineal',
    'careerName': 'Ingeniería Civil Informática',
    'fileType': 'pdf',
    'professor': 'Prof. Dr. Roberto Muñoz',
    'academicYear': 2026,
    'materialType': 'certamen',
    'status': 'aprobado',
    'downloadCount': 42,
    'rating': 4.8,
    'createdAt': '2026-10-05T14:00:00.000Z',
    'downloadUrl': '/materials/$testMaterialId/download',
    'fileSizeBytes': 1048576,
    'tags': ['Álgebra', 'Certamen'],
    'viewCount': 120,
    'currentVersion': {
      'id': 'ver_1',
      'versionNumber': 1,
      'originalFilename': 'certamen2_algebra.pdf',
      'mimeType': 'application/pdf',
      'fileSize': '1048576',
      'createdAt': '2026-10-05T14:00:00.000Z',
    },
    'currentVersionId': 'ver_1',
    'versions': [
      {
        'id': 'ver_1',
        'materialId': testMaterialId,
        'versionNumber': 1,
        'originalFileName': 'certamen2_algebra.pdf',
        'fileSizeBytes': 1048576,
        'mimeType': 'application/pdf',
      },
    ],
  };

  group('Detalle de Material con API Real (#290)', () {
    testWidgets(
      'Carga por ID y muestra metadata, archivo, estado y versión actual',
      (WidgetTester tester) async {
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          expect(options.path, '/materials/$testMaterialId');
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
            overrides: [apiclientProvider.overrideWithValue(apiClient)],
            child: MaterialApp(
              home: MaterialDetailScreen.byId(materialId: testMaterialId),
            ),
          ),
        );

        expect(find.byType(LoadingState), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.text('Certamen 2 Resuelto - Álgebra'), findsOneWidget);
        expect(find.text('Álgebra Lineal'), findsOneWidget);
        expect(find.text('APROBADO'), findsOneWidget);
        expect(find.text('Versión actual: v1'), findsOneWidget);
        expect(find.text('(certamen2_algebra.pdf)'), findsOneWidget);
        expect(find.text('Docente: Prof. Dr. Roberto Muñoz'), findsOneWidget);
        expect(find.text('Descargar Material'), findsOneWidget);
      },
    );

    testWidgets('No se desborda en pantallas pequeñas de 309px de ancho', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(309, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio();
      dio.httpClientAdapter = MockHttpAdapter((options) {
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
          overrides: [apiclientProvider.overrideWithValue(apiClient)],
          child: MaterialApp(
            home: MaterialDetailScreen.byId(materialId: testMaterialId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Versión actual: v1'), findsOneWidget);
    });

    testWidgets(
      'Material inexistente (404) muestra estado específico y botón volver',
      (WidgetTester tester) async {
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode({
              'statusCode': 404,
              'message': 'Material no encontrado',
            }),
            404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final apiClient = ApiClient(customDio: dio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiclientProvider.overrideWithValue(apiClient)],
            child: MaterialApp(
              home: MaterialDetailScreen.byId(materialId: 'mat_inexistente'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Material no encontrado'), findsOneWidget);
        expect(find.text('Volver al catálogo'), findsOneWidget);
      },
    );

    testWidgets('Error de red muestra estado de error y permite reintentar', (
      WidgetTester tester,
    ) async {
      bool shouldFail = true;
      final dio = Dio();
      dio.httpClientAdapter = MockHttpAdapter((options) {
        if (shouldFail) {
          return ResponseBody.fromString(
            jsonEncode({'statusCode': 500, 'message': 'Internal Server Error'}),
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
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
          overrides: [apiclientProvider.overrideWithValue(apiClient)],
          child: MaterialApp(
            home: MaterialDetailScreen.byId(materialId: testMaterialId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Certamen 2 Resuelto - Álgebra'), findsOneWidget);
    });
    testWidgets(
      'Error de red con initialSummary muestra ErrorState y permite reintentar',
      (WidgetTester tester) async {
        final dio = Dio();
        dio.httpClientAdapter = MockHttpAdapter((options) {
          return ResponseBody.fromString(
            jsonEncode({'statusCode': 500, 'message': 'Internal Server Error'}),
            500,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final apiClient = ApiClient(customDio: dio);

        const initialSummary = MaterialSummary(
          id: 'mat_con_resumen',
          title: 'Resumen Previo de Tarjeta',
          description: 'Descripción básica',
          authorName: 'Autor Previo',
          academicYear: 2026,
          materialType: 'guia',
          status: 'aprobado',
          downloadCount: 5,
          rating: 4.5,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiclientProvider.overrideWithValue(apiClient)],
            child: MaterialApp(
              home: MaterialDetailScreen.byId(
                materialId: 'mat_con_resumen',
                initialSummary: initialSummary,
              ),
            ),
          ),
        );

        // Primer frame: monta el widget y muestra resumen local en loading
        await tester.pump();
        // Espera a que termine la petición HTTP con error 500 y se reconstruya el árbol
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(
          find.text('No fue posible cargar el material. Verifica tu conexión.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });
}
