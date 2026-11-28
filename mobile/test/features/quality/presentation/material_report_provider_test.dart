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

class _ReportGatewayAdapter implements HttpClientAdapter {
  _ReportGatewayAdapter(this.data, {this.statusCode = 201});

  Object? data;
  int statusCode;
  final List<RequestOptions> requests = [];

  RequestOptions? get lastRequest =>
      requests.isEmpty ? null : requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bodyString = data != null ? jsonEncode(data) : '';
    return ResponseBody.fromString(
      bodyString,
      statusCode,
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
  const userUuid = '33333333-4444-4555-8666-777777777777';

  Future<ProviderContainer> createAuthenticatedContainer(
    _ReportGatewayAdapter adapter,
  ) async {
    final storage = MemorySessionStorage();
    final sessionController = SessionController(storage);
    final generation = sessionController.beginLogin();
    final loginPayload = loginFixture(
      email: 'estudiante@alu.uct.cl',
    );
    await sessionController.accept(
      AuthSession.fromLogin(loginPayload, DateTime.now().toUtc()),
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

  group('Issue #406: Conexión del envío de reportes con Quality (S3-M19)', () {
    test(
      'Criterio 1, 2 y 3: Envía el reporte por Gateway con materialId real, sesión compartida y cuerpo contractual',
      () async {
        final adapter = _ReportGatewayAdapter({
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'BROKEN_RESOURCE',
          'details': 'El enlace al documento devuelve 404.',
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T15:00:00Z',
          'updatedAt': '2026-11-21T15:00:00Z',
        }, statusCode: 201);

        final container = await createAuthenticatedContainer(adapter);
        final notifier = container.read(
          materialReportProvider(materialUuid).notifier,
        );

        final created = await notifier.submit(
          materialId: materialUuid,
          motive: ReportMotive.brokenResource,
          details: '  El enlace al documento devuelve 404.  ',
        );

        expect(created, isNotNull);
        expect(created!.id, reportUuid);
        expect(created.materialId, materialUuid);
        expect(created.reason, ReportReason.brokenResource);
        expect(created.status, ReportStatus.open);

        final req = adapter.lastRequest;
        expect(req?.method, 'POST');
        expect(req?.path, '/quality/materials/$materialUuid/reports');
        expect(
          req?.headers['Authorization'] as String?,
          startsWith('Bearer '),
        );
        expect(req?.headers['Idempotency-Key'], isNotNull);
        expect(req?.data, {
          'reason': 'BROKEN_RESOURCE',
          'details': 'El enlace al documento devuelve 404.',
        });

        final state = container.read(materialReportProvider(materialUuid));
        expect(state.isSuccess, isTrue);
        expect(state.submittedReport?.id, reportUuid);
      },
    );

    test(
      'Criterio 4: Un rechazo o servicio caído no se convierte en un reporte guardado localmente',
      () async {
        final adapter = _ReportGatewayAdapter({
          'statusCode': 503,
          'code': 'DEPENDENCY_UNAVAILABLE',
          'message': 'Quality Service no disponible.',
          'requestId': '11111111-1111-4111-8111-111111111111',
        }, statusCode: 503);

        final container = await createAuthenticatedContainer(adapter);
        final notifier = container.read(
          materialReportProvider(materialUuid).notifier,
        );

        final result = await notifier.submit(
          materialId: materialUuid,
          motive: ReportMotive.copyright,
          details: 'Copia textual sin permiso',
        );

        expect(result, isNull);
        final state = container.read(materialReportProvider(materialUuid));
        expect(state.isSuccess, isFalse);
        expect(state.submittedReport, isNull);
        expect(state.hasError, isTrue);
        expect(state.statusCode, 503);
        expect(state.errorCode, 'DEPENDENCY_UNAVAILABLE');
      },
    );

    test(
      'Cambiar o cerrar sesión reinicia el estado del reporte y evita conservar datos de otra cuenta',
      () async {
        final adapter = _ReportGatewayAdapter({
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'INAPPROPRIATE_CONTENT',
          'details': null,
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T15:00:00Z',
          'updatedAt': '2026-11-21T15:00:00Z',
        }, statusCode: 201);

        final container = await createAuthenticatedContainer(adapter);
        final sub = container.listen(
          materialReportProvider(materialUuid),
          (_, _) {},
        );
        addTearDown(sub.close);

        await container
            .read(materialReportProvider(materialUuid).notifier)
            .submit(
              materialId: materialUuid,
              motive: ReportMotive.inappropriateContent,
            );

        expect(
          container.read(materialReportProvider(materialUuid)).isSuccess,
          isTrue,
        );

        await container.read(sessionControllerProvider).clear();

        final afterLogout = container.read(
          materialReportProvider(materialUuid),
        );
        expect(afterLogout.isIdle, isTrue);
        expect(afterLogout.submittedReport, isNull);
      },
    );

    testWidgets(
      'MaterialReportForm conectado a materialReportProvider envía al Gateway real y notifica onReportCreated',
      (WidgetTester tester) async {
        final adapter = _ReportGatewayAdapter({
          'id': reportUuid,
          'materialId': materialUuid,
          'userId': userUuid,
          'reason': 'COPYRIGHT',
          'details': 'Material con derechos reservados.',
          'status': 'OPEN',
          'resolutionNote': null,
          'createdAt': '2026-11-21T15:00:00Z',
          'updatedAt': '2026-11-21T15:00:00Z',
        }, statusCode: 201);

        final container = await createAuthenticatedContainer(adapter);
        Report? confirmedReport;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Libro Escaneado',
                  onReportCreated: (r) => confirmedReport = r,
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
          'Material con derechos reservados.',
        );
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(confirmedReport, isNotNull);
        expect(confirmedReport!.id, reportUuid);
        expect(adapter.requests.length, 1);
        expect(
          adapter.lastRequest?.path,
          '/quality/materials/$materialUuid/reports',
        );
        await container.read(sessionControllerProvider).clear();
      },
    );

    testWidgets(
      'Regresión 401: Cuando un 401 limpia la sesión, el formulario conserva los datos y muestra que debe iniciar sesión nuevamente',
      (WidgetTester tester) async {
        final adapter = _ReportGatewayAdapter({
          'statusCode': 401,
          'code': 'UNAUTHENTICATED',
          'message': 'Token expirado o revocado.',
          'requestId': '11111111-1111-4111-8111-111111111199',
        }, statusCode: 401);

        final container = await createAuthenticatedContainer(adapter);
        expect(container.read(sessionControllerProvider).current, isNotNull);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes de Cálculo',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'El PDF no descarga completo.',
        );
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        // 1. SessionInterceptor limpió la sesión tras el 401
        expect(container.read(sessionControllerProvider).current, isNull);

        // 2. MaterialReportNotifier NO descartó el error 401 al limpiarse la sesión
        final state = container.read(materialReportProvider(materialUuid));
        expect(state.hasError, isTrue);
        expect(state.statusCode, 401);
        expect(state.errorCode, 'UNAUTHENTICATED');

        // 3. El formulario explica claramente que debe iniciar sesión nuevamente y conserva lo escrito
        expect(
          find.text(
            'Tu sesión expiró o no es válida. Debes iniciar sesión nuevamente para enviar el reporte.',
          ),
          findsOneWidget,
        );
        expect(find.text('El PDF no descarga completo.'), findsOneWidget);
        expect(find.text('Inicia sesión para enviar'), findsOneWidget);
      },
    );

    testWidgets(
      'Regresión 401 tardío: Un 401 de una credencial anterior que llega tras reautenticarse con la misma cuenta y credencial nueva NO pide login sobre la sesión nueva válida',
      (WidgetTester tester) async {
        final firstRequestCompleter = Completer<ResponseBody>();
        final adapter = _ReportGatewayAdapter(null);

        final storage = MemorySessionStorage();
        final sessionController = SessionController(storage);
        final gen1 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(
              email: 'estudiante@alu.uct.cl',
              lifetime: const Duration(hours: 1),
            ),
            DateTime.now().toUtc(),
          ),
          gen1,
        );

        final requests = <RequestOptions>[];
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://gateway.example.test/api/v1',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )..httpClientAdapter = _CallbackHttpAdapter((options) {
          requests.add(options);
          if (requests.length == 1) {
            return firstRequestCompleter.future;
          }
          return Future.value(
            ResponseBody.fromString(
              jsonEncode({
                'id': reportUuid,
                'materialId': materialUuid,
                'userId': userUuid,
                'reason': 'BROKEN_RESOURCE',
                'details': 'Enlace caído.',
                'status': 'OPEN',
                'resolutionNote': null,
                'createdAt': '2026-11-26T16:00:00Z',
                'updatedAt': '2026-11-26T16:00:00Z',
              }),
              201,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
          );
        });

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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes de Cálculo',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Enlace caído.');
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pump(const Duration(milliseconds: 10));
        expect(requests.length, 1);

        // El usuario vuelve a iniciar sesión con la MISMA cuenta y una credencial nueva
        final gen2 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(
              email: 'estudiante@alu.uct.cl',
              lifetime: const Duration(hours: 2),
            ),
            DateTime.now().toUtc(),
          ),
          gen2,
        );
        final newToken = sessionController.current?.accessToken;
        expect(newToken, isNotNull);

        // Llega tarde el 401 de la primera petición (con la credencial vieja)
        firstRequestCompleter.complete(
          ResponseBody.fromString(
            jsonEncode({
              'statusCode': 401,
              'code': 'UNAUTHENTICATED',
              'message': 'Credencial anterior expirada.',
            }),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await tester.pumpAndSettle();

        // La sesión nueva sigue válida y el formulario NO muestra aviso de login ni bloquea el envío
        expect(sessionController.current?.accessToken, equals(newToken));
        final stateAfterLate401 = container.read(
          materialReportProvider(materialUuid),
        );
        expect(stateAfterLate401.hasError, isFalse);
        expect(
          find.text(
            'Tu sesión expiró o no es válida. Debes iniciar sesión nuevamente para enviar el reporte.',
          ),
          findsNothing,
        );
        expect(find.text('Enviar Reporte'), findsOneWidget);
        expect(adapter.requests, isEmpty);

        await sessionController.clear();
      },
    );

    testWidgets(
      'Regresión login cancelado: Cancelar el nuevo login mientras el reporte anterior sigue en vuelo y recibir después su 401 NO deja el formulario en Enviando',
      (WidgetTester tester) async {
        final firstRequestCompleter = Completer<ResponseBody>();
        final storage = MemorySessionStorage();
        final sessionController = SessionController(storage);
        final gen1 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(email: 'estudiante@alu.uct.cl'),
            DateTime.now().toUtc(),
          ),
          gen1,
        );

        final requests = <RequestOptions>[];
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://gateway.example.test/api/v1',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )..httpClientAdapter = _CallbackHttpAdapter((options) {
          requests.add(options);
          return firstRequestCompleter.future;
        });

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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes de Cálculo',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Enlace roto.');
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pump(const Duration(milliseconds: 10));
        expect(requests.length, 1);
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isTrue,
        );

        // El usuario inicia un nuevo login y lo cancela mientras la petición anterior sigue en vuelo
        final gen2 = sessionController.beginLogin();
        await sessionController.cancelLogin(gen2);
        await tester.pump();

        // Al cambiar de sesión, el envío anterior deja de bloquear el formulario de inmediato
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isFalse,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Ahora llega tarde el 401 del reporte anterior
        firstRequestCompleter.complete(
          ResponseBody.fromString(
            jsonEncode({
              'statusCode': 401,
              'code': 'UNAUTHENTICATED',
              'message': 'Credencial anterior vencida.',
            }),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await tester.pumpAndSettle();

        // El formulario NO queda atrapado en Enviando
        final finalState = container.read(materialReportProvider(materialUuid));
        expect(finalState.isSubmitting, isFalse);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Enviar Reporte'), findsOneWidget);
      },
    );

    testWidgets(
      'Regresión JWT repetido y 502 tardío: Si el nuevo login devuelve el mismo JWT y la petición anterior termina en 502, NO bloquea en Enviando ni contamina la nueva sesión',
      (WidgetTester tester) async {
        final firstRequestCompleter = Completer<ResponseBody>();
        final fixedNow = DateTime.now().toUtc();
        final sameLoginPayload = loginFixture(
          email: 'estudiante@alu.uct.cl',
          now: fixedNow,
        );

        final storage = MemorySessionStorage();
        final sessionController = SessionController(storage);
        final gen1 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(sameLoginPayload, fixedNow),
          gen1,
        );
        final initialJwt = sessionController.current?.accessToken;

        final requests = <RequestOptions>[];
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://gateway.example.test/api/v1',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )..httpClientAdapter = _CallbackHttpAdapter((options) {
          requests.add(options);
          return firstRequestCompleter.future;
        });

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

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: MaterialReportForm(
                  materialId: materialUuid,
                  materialTitle: 'Apuntes de Cálculo',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recurso dañado o enlace roto').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Archivo corrupto.');
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pump(const Duration(milliseconds: 10));
        expect(requests.length, 1);

        // El nuevo login devuelve exactamente el MISMO JWT
        final gen2 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(sameLoginPayload, fixedNow),
          gen2,
        );
        await tester.pump();
        expect(sessionController.current?.accessToken, equals(initialJwt));

        // El formulario ya fue desbloqueado por el cambio de sesión
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isFalse,
        );

        // La petición anterior termina en 502 tardío
        firstRequestCompleter.complete(
          ResponseBody.fromString(
            jsonEncode({
              'statusCode': 502,
              'code': 'DEPENDENCY_INVALID_RESPONSE',
              'message': 'Bad Gateway tardío.',
            }),
            502,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        await tester.pumpAndSettle();

        // Ni queda en Enviando ni muestra el 502 de la operación reemplazada
        final stateAfterLate502 = container.read(
          materialReportProvider(materialUuid),
        );
        expect(stateAfterLate502.isSubmitting, isFalse);
        expect(stateAfterLate502.hasError, isFalse);
        expect(stateAfterLate502.isIdle, isTrue);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Enviar Reporte'), findsOneWidget);

        await sessionController.clear();
      },
    );

    test(
      'Regresión respuesta tardía con otro envío en curso: Una respuesta tardía del envío anterior NO modifica el estado mientras hay un nuevo envío vigente',
      () async {
        final firstCompleter = Completer<ResponseBody>();
        final secondCompleter = Completer<ResponseBody>();
        var callCount = 0;

        final storage = MemorySessionStorage();
        final sessionController = SessionController(storage);
        final gen1 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(email: 'estudiante@alu.uct.cl'),
            DateTime.now().toUtc(),
          ),
          gen1,
        );

        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://gateway.example.test/api/v1',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )..httpClientAdapter = _CallbackHttpAdapter((_) {
          callCount++;
          if (callCount == 1) {
            return firstCompleter.future;
          }
          return secondCompleter.future;
        });

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
        final sub = container.listen(
          materialReportProvider(materialUuid),
          (_, _) {},
        );
        addTearDown(() {
          sub.close();
          sessionController.dispose();
          dio.close(force: true);
          container.dispose();
        });

        // 1. Primer envío en la sesión 1 (queda en vuelo)
        final firstFuture = container
            .read(materialReportProvider(materialUuid).notifier)
            .submit(
              materialId: materialUuid,
              motive: ReportMotive.brokenResource,
              details: 'Primer envío.',
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isTrue,
        );

        // 2. Cambio de sesión -> desbloquea el formulario para permitir un nuevo envío
        final gen2 = sessionController.beginLogin();
        await sessionController.accept(
          AuthSession.fromLogin(
            loginFixture(
              email: 'estudiante@alu.uct.cl',
              lifetime: const Duration(hours: 2),
            ),
            DateTime.now().toUtc(),
          ),
          gen2,
        );
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isFalse,
        );

        // 3. Segundo envío en la sesión 2 (queda en curso como operación vigente)
        final secondFuture = container
            .read(materialReportProvider(materialUuid).notifier)
            .submit(
              materialId: materialUuid,
              motive: ReportMotive.copyright,
              details: 'Segundo envío vigente.',
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(materialReportProvider(materialUuid)).isSubmitting,
          isTrue,
        );

        // 4. Llega la respuesta tardía (502) del primer envío mientras el segundo está en curso
        firstCompleter.complete(
          ResponseBody.fromString(
            jsonEncode({
              'statusCode': 502,
              'code': 'DEPENDENCY_INVALID_RESPONSE',
              'message': 'Fallo tardío del primer envío.',
            }),
            502,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        expect(await firstFuture, isNull);

        // El segundo envío sigue en curso y NO fue sobrescrito por el 502 tardío
        final midState = container.read(materialReportProvider(materialUuid));
        expect(midState.isSubmitting, isTrue);
        expect(midState.hasError, isFalse);

        // 5. Termina exitosamente el segundo envío
        secondCompleter.complete(
          ResponseBody.fromString(
            jsonEncode({
              'id': reportUuid,
              'materialId': materialUuid,
              'userId': userUuid,
              'reason': 'COPYRIGHT',
              'details': 'Segundo envío vigente.',
              'status': 'OPEN',
              'resolutionNote': null,
              'createdAt': '2026-11-27T12:00:00Z',
              'updatedAt': '2026-11-27T12:00:00Z',
            }),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
        final secondResult = await secondFuture;
        expect(secondResult, isNotNull);
        expect(secondResult!.id, reportUuid);

        final finalState = container.read(materialReportProvider(materialUuid));
        expect(finalState.isSuccess, isTrue);
        expect(finalState.submittedReport?.id, reportUuid);
      },
    );
  });
}

class _CallbackHttpAdapter implements HttpClientAdapter {
  _CallbackHttpAdapter(this._handler);
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}
