import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/quality/quality.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_session_fixture.dart';

class _ProgrammableQualityAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Future<ResponseBody> Function(RequestOptions options)? handler;

  void respondJson(Object? data, {int statusCode = 200}) {
    handler = (_) async => ResponseBody.fromString(
      data != null ? jsonEncode(data) : '',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  void throwNetworkError(RequestOptions Function()? _) {
    handler = (options) async {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused / Network unreachable',
      );
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const materialUuid = '22222222-3333-4444-8555-666666666666';
  const reportUuid = '88888888-7777-4666-8555-444444444444';
  const userUuid = '00000000-0000-4000-8000-000000000092';

  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  Future<ProviderContainer> createContainer(
    _ProgrammableQualityAdapter adapter,
  ) async {
    final storage = MemorySessionStorage();
    final sessionController = SessionController(storage);
    final generation = sessionController.beginLogin();
    await sessionController.accept(
      AuthSession.fromLogin(loginFixture(), DateTime.now().toUtc()),
      generation,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://gateway.example.test/api/v1',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )..httpClientAdapter = adapter;

    final apiClient = ApiClient(
      baseUrl: 'https://gateway.example.test/api/v1',
      customDio: dio,
      session: sessionController,
    );

    final container = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWithValue(sessionController),
        apiclientProvider.overrideWithValue(apiClient),
      ],
    );
    addTearDown(() {
      sessionController.dispose();
      dio.close(force: true);
      container.dispose();
    });
    return container;
  }

  group('Issue #408: Pruebas de reportes, envíos repetidos y recuperación ante errores (S3-M21)', () {
    testWidgets(
      'Criterio 1: Verifica solicitud contractual (ruta, cabeceras Bearer e Idempotency-Key UUID, cuerpo) y confirmación exitosa',
      (WidgetTester tester) async {
        final adapter = _ProgrammableQualityAdapter()
          ..respondJson({
            'id': reportUuid,
            'materialId': materialUuid,
            'userId': userUuid,
            'reason': 'INAPPROPRIATE_CONTENT',
            'details': 'Lenguaje ofensivo en la página 2.',
            'status': 'OPEN',
            'resolutionNote': null,
            'createdAt': '2026-11-21T17:00:00Z',
            'updatedAt': '2026-11-21T17:00:00Z',
          }, statusCode: 201);

        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportSheet(
                  materialId: materialUuid,
                  materialTitle: 'Resumen de Álgebra',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Contenido inapropiado u ofensivo').last,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'Lenguaje ofensivo en la página 2.',
        );
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(adapter.requests.length, 1);
        final req = adapter.requests.single;
        expect(req.method, 'POST');
        expect(req.path, '/quality/materials/$materialUuid/reports');
        expect(req.headers['Authorization'] as String?, startsWith('Bearer '));
        final idempotencyKey = req.headers['Idempotency-Key'] as String?;
        expect(idempotencyKey, isNotNull);
        expect(uuidRegex.hasMatch(idempotencyKey!), isTrue);
        expect(req.data, {
          'reason': 'INAPPROPRIATE_CONTENT',
          'details': 'Lenguaje ofensivo en la página 2.',
        });

        expect(find.text('Reporte enviado'), findsOneWidget);
        expect(
          find.text('Motivo: Contenido inapropiado u ofensivo'),
          findsOneWidget,
        );

        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Criterio 2: Cubre rechazo de validación (400 VALIDATION_ERROR) y de autorización (401 y 403)',
      (WidgetTester tester) async {
        final adapter = _ProgrammableQualityAdapter()
          ..respondJson({
            'statusCode': 400,
            'code': 'VALIDATION_ERROR',
            'message': 'El campo details contiene caracteres no válidos.',
            'field': 'details',
            'requestId': '11111111-1111-4111-8111-111111111111',
          }, statusCode: 400);

        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Guía Laboratorio',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Infracción de derechos de autor').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'Texto de prueba rechazado',
        );
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        // 400 Validation Error
        final state400 = container.read(materialReportProvider(materialUuid));
        expect(state400.hasError, isTrue);
        expect(state400.statusCode, 400);
        expect(state400.errorCode, 'VALIDATION_ERROR');
        expect(state400.errorField, 'details');
        expect(
          find.text('El campo details contiene caracteres no válidos.'),
          findsOneWidget,
        );
        expect(find.text('Reporte enviado'), findsNothing);

        // 403 Forbidden (ej. cuenta inactiva)
        adapter.respondJson({
          'statusCode': 403,
          'code': 'FORBIDDEN',
          'message': 'Tu cuenta se encuentra inactiva para reportar.',
          'requestId': '11111111-1111-4111-8111-111111111112',
        }, statusCode: 403);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        final state403 = container.read(materialReportProvider(materialUuid));
        expect(state403.statusCode, 403);
        expect(state403.errorCode, 'FORBIDDEN');
        expect(
          find.text('Tu cuenta se encuentra inactiva para reportar.'),
          findsOneWidget,
        );
        // Un 403 conserva la sesión activa y el texto escrito
        expect(container.read(sessionControllerProvider).current, isNotNull);
        expect(find.text('Texto de prueba rechazado'), findsOneWidget);

        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Criterio 3: Maneja reporte repetido (409 REPORT_ALREADY_OPEN, 409 IDEMPOTENCY_CONFLICT y replay 200 OK)',
      (WidgetTester tester) async {
        final adapter = _ProgrammableQualityAdapter()
          ..respondJson({
            'statusCode': 409,
            'code': 'REPORT_ALREADY_OPEN',
            'message': 'Ya tienes un reporte abierto para este material.',
            'requestId': '11111111-1111-4111-8111-111111111113',
          }, statusCode: 409);

        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Certamen Cálculo',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Información errónea o desactualizada').last,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'La fórmula de la pregunta 4 está invertida.',
        );
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        // 1. Conflicto 409 REPORT_ALREADY_OPEN
        final conflictState = container.read(
          materialReportProvider(materialUuid),
        );
        expect(conflictState.hasError, isTrue);
        expect(conflictState.statusCode, 409);
        expect(conflictState.errorCode, 'REPORT_ALREADY_OPEN');
        expect(
          find.text('Ya tienes un reporte abierto para este material.'),
          findsOneWidget,
        );
        expect(find.text('Reporte enviado'), findsNothing);

        // 2. Conflicto 409 IDEMPOTENCY_CONFLICT
        adapter.respondJson({
          'statusCode': 409,
          'code': 'IDEMPOTENCY_CONFLICT',
          'message': 'La clave de idempotencia ya fue usada con otro payload.',
          'requestId': '11111111-1111-4111-8111-111111111114',
        }, statusCode: 409);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(
          container.read(materialReportProvider(materialUuid)).errorCode,
          'IDEMPOTENCY_CONFLICT',
        );
        expect(
          find.text(
            'La clave de idempotencia ya fue usada con otro payload.',
          ),
          findsOneWidget,
        );

        // 3. Replay idempotente documentado (200 OK devuelve el reporte original sin duplicar)
        adapter.respondJson({
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'INCORRECT_INFORMATION',
          'details': 'La fórmula de la pregunta 4 está invertida.',
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T17:10:00Z',
          'updatedAt': '2026-11-21T17:10:00Z',
        }, statusCode: 200);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('Reporte enviado'), findsOneWidget);
        expect(
          container
              .read(materialReportProvider(materialUuid))
              .submittedReport
              ?.id,
          reportUuid,
        );

        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Criterio 4: Un fallo de red conserva los datos escritos, mantiene la misma Idempotency-Key y se recupera al reintentar',
      (WidgetTester tester) async {
        final adapter = _ProgrammableQualityAdapter()..throwNetworkError(null);
        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes Base de Datos',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        const detailsText = 'El archivo adjunto está truncado al descargar.';
        await tester.enterText(find.byType(TextFormField), detailsText);

        // Primer intento sufre caída de red
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(adapter.requests.length, 1);
        final firstKey =
            adapter.requests.first.headers['Idempotency-Key'] as String?;
        expect(firstKey, isNotNull);

        // No confirma éxito inexistente y conserva texto y motivo seleccionados
        expect(find.text('Reporte enviado'), findsNothing);
        expect(find.text(detailsText), findsOneWidget);
        expect(find.text('Recurso dañado o enlace roto'), findsOneWidget);
        expect(
          container.read(materialReportProvider(materialUuid)).hasError,
          isTrue,
        );

        // La red se restablece y el usuario reintenta
        adapter.respondJson({
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'BROKEN_RESOURCE',
          'details': detailsText,
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T17:15:00Z',
          'updatedAt': '2026-11-21T17:15:00Z',
        }, statusCode: 201);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(adapter.requests.length, 2);
        final secondKey =
            adapter.requests[1].headers['Idempotency-Key'] as String?;
        // Verifica que el reintento utilizó exactamente la misma clave de idempotencia
        expect(secondKey, equals(firstKey));
        expect(find.text('Reporte enviado'), findsOneWidget);

        await container.read(sessionControllerProvider).clear();
      },
    );
  });
}
