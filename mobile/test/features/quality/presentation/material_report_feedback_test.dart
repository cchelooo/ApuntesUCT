import 'dart:async';
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

class _ControllableReportAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Completer<ResponseBody>? pendingResponse;
  Object? nextData;
  int nextStatusCode = 201;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (pendingResponse != null) {
      return pendingResponse!.future;
    }
    final bodyString = nextData != null ? jsonEncode(nextData) : '';
    return ResponseBody.fromString(
      bodyString,
      nextStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const materialUuid = '11111111-2222-4333-8444-555555555555';
  const reportUuid = '99999999-8888-4777-8666-555555555555';
  const userUuid = '00000000-0000-4000-8000-000000000092';

  Future<ProviderContainer> createContainer(
    _ControllableReportAdapter adapter,
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

  group('Issue #407: Confirmación, carga y errores al enviar reportes (S3-M20)', () {
    testWidgets(
      'Criterio 1, 2 y 4: Muestra carga mientras está pendiente, bloquea envíos duplicados y confirma sólo tras respuesta exitosa',
      (WidgetTester tester) async {
        final adapter = _ControllableReportAdapter();
        adapter.pendingResponse = Completer<ResponseBody>();
        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes de Redes',
                ),
              ),
            ),
          ),
        );

        // Seleccionar motivo y escribir detalle
        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'El archivo PDF no abre en la página 3.',
        );

        // Primer toque inicia el envío
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pump(const Duration(milliseconds: 10));

        // Criterio 1: Se muestra carga mientras la solicitud está pendiente
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Enviando reporte...'), findsOneWidget);
        // Criterio 2: La confirmación NO se muestra mientras la respuesta está pendiente
        expect(find.text('Reporte enviado'), findsNothing);

        // Criterio 4: Intentar tocar repetidamente o invocar submit no dispara solicitudes duplicadas
        await tester.tap(
          find.byType(ElevatedButton),
          warnIfMissed: false,
        );
        await container
            .read(materialReportProvider(materialUuid).notifier)
            .submit(
              materialId: materialUuid,
              motive: ReportMotive.brokenResource,
              details: 'Intento duplicado',
            );
        await tester.pump(const Duration(milliseconds: 10));
        expect(adapter.requests.length, 1);

        // Completar respuesta exitosa del servidor
        adapter.pendingResponse!.complete(
          ResponseBody.fromString(
            jsonEncode({
              'id': reportUuid,
              'materialId': materialUuid,
              'userId': userUuid,
              'reason': 'BROKEN_RESOURCE',
              'details': 'El archivo PDF no abre en la página 3.',
              'status': 'OPEN',
              'resolutionNote': null,
              'createdAt': '2026-11-21T16:00:00Z',
              'updatedAt': '2026-11-21T16:00:00Z',
            }),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await tester.pumpAndSettle();

        // Criterio 2: La confirmación aparece únicamente tras la respuesta exitosa
        expect(find.text('Reporte enviado'), findsOneWidget);
        expect(
          find.textContaining('Apuntes de Redes'),
          findsOneWidget,
        );
        expect(
          find.text('Motivo: Recurso dañado o enlace roto'),
          findsOneWidget,
        );

        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Criterio 3: Los errores conservan el motivo y texto escrito y permiten reintentar',
      (WidgetTester tester) async {
        final adapter = _ControllableReportAdapter()
          ..nextStatusCode = 502
          ..nextData = {
            'statusCode': 502,
            'code': 'DEPENDENCY_INVALID_RESPONSE',
            'message': 'Quality Service no disponible.',
            'requestId': '11111111-1111-4111-8111-111111111111',
          };
        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Guía de Física',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Otro motivo').last);
        await tester.pumpAndSettle();

        const writtenDetails = 'Faltan las páginas pares del capítulo 2.';
        await tester.enterText(find.byType(TextFormField), writtenDetails);

        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        // Muestra error, NO muestra confirmación y conserva lo escrito
        expect(find.text('Reporte enviado'), findsNothing);
        expect(
          find.textContaining('El servicio de calidad no está disponible'),
          findsOneWidget,
        );
        expect(find.text(writtenDetails), findsOneWidget);
        expect(find.text('Otro motivo'), findsOneWidget);

        // El servidor se recupera y el usuario pulsa Reintentar
        adapter.nextStatusCode = 201;
        adapter.nextData = {
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'OTHER',
          'details': writtenDetails,
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T16:05:00Z',
          'updatedAt': '2026-11-21T16:05:00Z',
        };

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(adapter.requests.length, 2);
        // La clave de idempotencia se conservó entre el fallo y el reintento
        expect(
          adapter.requests[1].headers['Idempotency-Key'],
          equals(adapter.requests[0].headers['Idempotency-Key']),
        );
        expect(find.text('Reporte enviado'), findsOneWidget);

        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Regresión 401 sin Authorization: Tras un 401 que limpia la sesión, NO ofrece Reintentar ni envía otro POST sin Authorization hasta reautenticarse',
      (WidgetTester tester) async {
        final adapter = _ControllableReportAdapter()
          ..nextStatusCode = 401
          ..nextData = {
            'statusCode': 401,
            'code': 'UNAUTHENTICATED',
            'message': 'Token expirado.',
          };
        final container = await createContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Guía de Química',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        const writtenDetails = 'El documento tiene páginas en blanco.';
        await tester.enterText(find.byType(TextFormField), writtenDetails);

        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        // 1. El primer POST recibió 401 y limpió la sesión
        expect(adapter.requests.length, 1);
        expect(container.read(sessionControllerProvider).current, isNull);

        // 2. El formulario conserva lo escrito, pide reautenticación y NO ofrece "Reintentar"
        expect(find.text(writtenDetails), findsOneWidget);
        expect(find.text('Recurso dañado o enlace roto'), findsOneWidget);
        expect(find.text('Reintentar'), findsNothing);
        expect(find.text('Inicia sesión para enviar'), findsOneWidget);

        // 3. Intentar pulsar el botón o invocar submit sin sesión NO envía un POST sin Authorization
        await tester.tap(
          find.byType(ElevatedButton),
          warnIfMissed: false,
        );
        await container
            .read(materialReportProvider(materialUuid).notifier)
            .submit(
              materialId: materialUuid,
              motive: ReportMotive.brokenResource,
              details: writtenDetails,
            );
        await tester.pumpAndSettle();
        expect(adapter.requests.length, 1);

        // 4. Al reautenticarse, el formulario habilita el envío conservando lo escrito y envía con Authorization
        final sessionController = container.read(sessionControllerProvider);
        final newGen = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(lifetime: const Duration(hours: 2)),
            DateTime.now().toUtc(),
          ),
          newGen,
        );
        await tester.pumpAndSettle();

        expect(find.text(writtenDetails), findsOneWidget);
        expect(find.text('Enviar Reporte'), findsOneWidget);

        adapter.nextStatusCode = 201;
        adapter.nextData = {
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'BROKEN_RESOURCE',
          'details': writtenDetails,
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-26T16:30:00Z',
          'updatedAt': '2026-11-26T16:30:00Z',
        };

        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(adapter.requests.length, 2);
        expect(
          adapter.requests[1].headers['Authorization'] as String?,
          startsWith('Bearer '),
        );
        expect(find.text('Reporte enviado'), findsOneWidget);

        await sessionController.clear();
      },
    );
  });
}
