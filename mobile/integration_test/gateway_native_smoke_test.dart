import 'dart:io';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_route.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:apuntesuct_mobile/main.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Opt-in. No sustituye repositorios, transporte ni plugins. Requiere un PDF
// publicado y referencias académicas en un entorno de prueba ya preparado.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_NATIVE_GATEWAY_SMOKE');
  const materialId = String.fromEnvironment('EXPECTED_MATERIAL_ID');
  const title = String.fromEnvironment('EXPECTED_MATERIAL_TITLE');
  const subject = String.fromEnvironment('EXPECTED_SUBJECT_NAME');

  testWidgets('Arranque y recorrido nativo mediante Gateway real', (
    tester,
  ) async {
    expect(materialId, isNotEmpty, reason: 'Falta EXPECTED_MATERIAL_ID');
    expect(title, isNotEmpty, reason: 'Falta EXPECTED_MATERIAL_TITLE');
    expect(subject, isNotEmpty, reason: 'Falta EXPECTED_SUBJECT_NAME');
    final container = ProviderContainer();
    final client = container.read(apiclientProvider);
    final responses = <String>[];
    final requestUris = <Uri>[];
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final request = response.requestOptions;
          requestUris.add(request.uri);
          responses.add(
            '${request.method} ${request.uri.path} ${response.statusCode}',
          );
          handler.next(response);
        },
      ),
    );
    addTearDown(() {
      client.dio.close(force: true);
      container.dispose();
    });
    app.appRouter.go('/login');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const app.MyApp()),
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    await binding.takeScreenshot('login');

    // Auth responde por HTTP, pero su login del Sprint 2 sigue siendo simulado.
    await tester.enterText(find.byType(TextFormField).at(0), 'qa278');
    await tester.enterText(find.byType(TextFormField).at(1), 'smoke-only');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingresar'));
    await _waitFor(
      tester,
      () => find.text('Explorar materiales').evaluate().isNotEmpty,
    );
    expect(responses, contains('POST /api/v1/auth/login 200'));

    app.appRouter.go('/catalog');
    await _waitFor(tester, () => find.text(subject).evaluate().isNotEmpty);
    expect(responses, contains('GET /api/v1/catalog 200'));
    await binding.takeScreenshot('catalogo');

    app.appRouter.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar materiales'));
    await _waitFor(
      tester,
      () => !container.read(discoveryMaterialsProvider).isLoading,
    );
    expect(
      container.read(discoveryMaterialsProvider).items.map((item) => item.id),
      contains(materialId),
    );
    expect(responses, contains('GET /api/v1/materials 200'));
    await binding.takeScreenshot('listado');

    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(TextField),
      ),
      title,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _waitFor(tester, () {
      final state = container.read(discoveryMaterialsProvider);
      return state.query == title && !state.isLoading;
    });
    expect(responses, contains('GET /api/v1/search 200'));
    expect(
      container.read(discoveryMaterialsProvider).items.map((item) => item.id),
      contains(materialId),
    );
    await binding.takeScreenshot('busqueda');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is MaterialSummaryCard && widget.material.id == materialId,
      ),
    );
    await _waitFor(
      tester,
      () => find.text('Descargar Material').evaluate().isNotEmpty,
    );
    expect(
      tester
          .widget<MaterialDetailRoute>(find.byType(MaterialDetailRoute))
          .materialId,
      materialId,
    );
    expect(responses, contains('GET /api/v1/materials/$materialId 200'));
    await binding.takeScreenshot('detalle');

    await tester.ensureVisible(find.text('Descargar Material'));
    await tester.tap(find.text('Descargar Material'));
    await _waitFor(
      tester,
      () =>
          container.read(materialDownloadProvider).hasValue &&
          container.read(materialDownloadProvider).value != null,
    );
    final result = container.read(materialDownloadProvider).requireValue!;
    expect(result.materialId, materialId);
    expect(result.download.mimeType, contains('application/pdf'));
    expect(await File(result.savedPath).readAsBytes(), result.download.bytes);
    expect(result.download.bytes.take(5), '%PDF-'.codeUnits);
    expect(find.text('Abrir archivo'), findsOneWidget);
    expect(
      responses,
      contains('GET /api/v1/materials/$materialId/download 200'),
    );
    await binding.takeScreenshot('descarga');
    final gateway = Uri.parse(client.dio.options.baseUrl);
    expect(requestUris, isNotEmpty);
    for (final uri in requestUris) {
      expect(uri.origin, gateway.origin);
      expect(uri.path, startsWith('/api/v1/'));
    }
    binding.reportData = {
      ...?binding.reportData,
      'gateway': client.dio.options.baseUrl,
      'responses': responses,
      'requestUris': requestUris.map((uri) => uri.toString()).toList(),
      'materialId': materialId,
      'downloadBytes': result.download.bytes.length,
    };
    expect(tester.takeException(), isNull);
  }, skip: !enabled);
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  } while (DateTime.now().isBefore(deadline));
  fail('El estado esperado no apareció en 30 segundos.');
}
