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
  });
}
