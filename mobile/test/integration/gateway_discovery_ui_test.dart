import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_route.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/gateway_contract_fixtures.dart';
import '../helpers/gateway_test_transport.dart';

final materialId = materialSummary(1)['id'] as String;
Map<String, dynamic> listing() => {
  'items': [materialSummary(1)],
  'page': 1,
  'pageSize': 5,
  'total': 1,
};

Future<void> mount(
  WidgetTester tester,
  GatewayTestTransport transport, {
  String initial = '/materials',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/materials',
        builder: (context, state) => const MaterialDiscoveryScreen(),
      ),
      GoRoute(
        path: '/materials/:id',
        builder: (context, state) =>
            MaterialDetailRoute(materialId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = gatewayTestContainer(transport);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const Key('capture'),
        child: MaterialApp.router(
          theme: ThemeData(fontFamily: 'Roboto'),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Search 502 llega a la pantalla y reintentar muestra cero resultados reales',
    (tester) async {
      var failing = true;
      final transport = GatewayTestTransport((request) {
        if (request.path == '/materials') {
          expect(
            request.uri.toString(),
            '$testGatewayUrl/materials?page=1&pageSize=5',
          );
          return gatewayJson(listing());
        }
        expect(
          request.uri.toString(),
          '$testGatewayUrl/search?q=redes&page=1&pageSize=5',
        );
        if (failing) {
          return gatewayJson({
            'statusCode': 502,
            'message': 'Search está temporalmente fuera de servicio',
          }, status: 502);
        }
        return gatewayJson({
          ...searchResponse(query: 'redes', pageSize: 5, total: 0),
          'context': [],
        });
      });
      await mount(tester, transport);
      expect(find.byType(MaterialSummaryCard), findsOneWidget);
      await tester.enterText(find.byType(SearchBar), 'redes');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);
      expect(
        find.text('Search está temporalmente fuera de servicio'),
        findsOneWidget,
      );
      expect(find.byType(MaterialSummaryCard), findsNothing);
      failing = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin coincidencias'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
      expect(transport.requests, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tarjeta → ruta real → 404 no sustituye el detalle por un fixture',
    (tester) async {
      final transport = GatewayTestTransport((request) {
        if (request.path == '/materials') return gatewayJson(listing());
        expect(request.uri.toString(), '$testGatewayUrl/materials/$materialId');
        return gatewayJson({
          'statusCode': 404,
          'message': 'Material no encontrado',
        }, status: 404);
      });
      await mount(tester, transport);
      await tester.tap(find.byType(MaterialSummaryCard));
      await tester.pumpAndSettle();
      expect(find.text('Material no encontrado'), findsOneWidget);
      expect(find.text('Apunte 1'), findsNothing);
      expect(find.text('Descargar Material'), findsNothing);
      expect(transport.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detalle 502 conserva mensaje útil y permite reintentar la misma ruta',
    (tester) async {
      final transport = GatewayTestTransport((request) {
        expect(request.uri.toString(), '$testGatewayUrl/materials/$materialId');
        return gatewayJson({
          'statusCode': 502,
          'message': 'Material no puede consultar el almacenamiento',
        }, status: 502);
      });
      await mount(tester, transport, initial: '/materials/$materialId');
      expect(find.byType(ErrorState), findsOneWidget);
      expect(
        find.text('Material no puede consultar el almacenamiento'),
        findsOneWidget,
      );
      expect(find.text('Material no encontrado'), findsNothing);
      expect(find.text('Descargar Material'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(transport.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timeout de listado llega a la interfaz sin datos de ejemplo', (
    tester,
  ) async {
    final transport = GatewayTestTransport((request) {
      expect(
        request.uri.toString(),
        '$testGatewayUrl/materials?page=1&pageSize=5',
      );
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionTimeout,
      );
    });
    await mount(tester, transport);
    expect(
      find.text('Tiempo de espera agotado al conectar con el servidor.'),
      findsOneWidget,
    );
    expect(find.byType(MaterialSummaryCard), findsNothing);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(transport.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
