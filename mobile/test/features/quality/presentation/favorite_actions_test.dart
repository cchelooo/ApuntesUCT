import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:apuntesuct_mobile/features/quality/quality.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_session_fixture.dart';

class _FavoriteGatewayAdapter implements HttpClientAdapter {
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
  const newMaterialUuid = '55555555-6666-4777-8888-999999999999';
  const newFavoriteUuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

  final sampleMaterial = const MaterialSummary(
    id: newMaterialUuid,
    title: 'Apuntes de Sistemas Operativos',
    subjectName: 'Sistemas Operativos',
    careerName: 'Ingeniería Civil Informática',
    authorName: 'Prof. Luis Torres',
    academicYear: 2025,
    materialType: 'DOCUMENT',
    status: 'PUBLISHED',
  );

  Future<ProviderContainer> createSessionContainer(
    _FavoriteGatewayAdapter adapter, {
    String email = 'estudiante@alu.uct.cl',
  }) async {
    final storage = MemorySessionStorage();
    final sessionController = SessionController(storage);
    final generation = sessionController.beginLogin();
    await sessionController.accept(
      AuthSession.fromLogin(
        loginFixture(email: email),
        DateTime.now().toUtc(),
      ),
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

  group('Issue #418: Acciones de agregar y quitar favoritos (S3-M31)', () {
    test(
      'Criterio 1 y 2: Agregar y quitar utilizan el material y usuario autenticado mediante Gateway y sincronizan listado',
      () async {
        final adapter = _FavoriteGatewayAdapter()
          ..respondJson({
            'id': newFavoriteUuid,
            'materialId': newMaterialUuid,
            'createdAt': '2026-11-23T14:00:00Z',
            'available': true,
          }, statusCode: 201);

        final container = await createSessionContainer(adapter);
        final subFavs = container.listen(favoritesProvider, (_, _) {});
        final subAction = container.listen(
          favoriteActionProvider(newMaterialUuid),
          (_, _) {},
        );
        addTearDown(() {
          subAction.close();
          subFavs.close();
        });

        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isFalse,
        );

        // 1. Agregar favorito (PUT /quality/materials/:id/favorite)
        final addedOk = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .addFavorite(summary: sampleMaterial);

        expect(addedOk, isTrue);
        expect(adapter.requests.length, 1);
        final putReq = adapter.requests.first;
        expect(putReq.method, 'PUT');
        expect(putReq.path, '/quality/materials/$newMaterialUuid/favorite');
        expect(
          putReq.headers['Authorization'] as String?,
          startsWith('Bearer '),
        );

        // Estado confirmado tanto en action provider como en listado de favoritos
        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isTrue,
        );
        expect(
          container.read(favoritesProvider).containsMaterial(newMaterialUuid),
          isTrue,
        );

        // 2. Quitar favorito (DELETE /quality/materials/:id/favorite)
        adapter.respondJson(null, statusCode: 204);
        final removedOk = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .removeFavorite();

        expect(removedOk, isTrue);
        expect(adapter.requests.length, 2);
        final delReq = adapter.requests.last;
        expect(delReq.method, 'DELETE');
        expect(delReq.path, '/quality/materials/$newMaterialUuid/favorite');
        expect(
          delReq.headers['Authorization'] as String?,
          startsWith('Bearer '),
        );

        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isFalse,
        );
        expect(
          container.read(favoritesProvider).containsMaterial(newMaterialUuid),
          isFalse,
        );
      },
    );

    test(
      'Criterio 3: Un error conserva el estado confirmado previo y permite reintentar',
      () async {
        final adapter = _FavoriteGatewayAdapter()
          ..respondJson({
            'statusCode': 503,
            'code': 'DEPENDENCY_UNAVAILABLE',
            'message': 'Quality Service no disponible.',
            'requestId': '11111111-1111-4111-8111-111111111111',
          }, statusCode: 503);

        final container = await createSessionContainer(adapter);
        final subAction = container.listen(
          favoriteActionProvider(newMaterialUuid),
          (_, _) {},
        );
        addTearDown(subAction.close);

        // Intento de agregar falla con 503 -> no debe marcarse como favorito falso
        final ok = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .addFavorite(summary: sampleMaterial);

        expect(ok, isFalse);
        final errState = container.read(
          favoriteActionProvider(newMaterialUuid),
        );
        expect(errState.isFavorite, isFalse);
        expect(errState.hasError, isTrue);
        expect(errState.canRetry, isTrue);
        expect(errState.statusCode, 503);

        // El servicio se recupera y retry() completa el guardado
        adapter.respondJson({
          'id': newFavoriteUuid,
          'materialId': newMaterialUuid,
          'createdAt': '2026-11-23T14:05:00Z',
          'available': true,
        }, statusCode: 201);

        final retryOk = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .retry();

        expect(retryOk, isTrue);
        final confirmedState = container.read(
          favoriteActionProvider(newMaterialUuid),
        );
        expect(confirmedState.isFavorite, isTrue);
        expect(confirmedState.hasError, isFalse);

        // Ahora falla al intentar quitar (DELETE falla con 502) -> conserva isFavorite: true
        adapter.respondJson({
          'statusCode': 502,
          'code': 'DEPENDENCY_INVALID_RESPONSE',
          'message': 'Error de Gateway.',
        }, statusCode: 502);

        final removeOk = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .removeFavorite();

        expect(removeOk, isFalse);
        final errRemoveState = container.read(
          favoriteActionProvider(newMaterialUuid),
        );
        expect(errRemoveState.isFavorite, isTrue);
        expect(errRemoveState.hasError, isTrue);

        // Reintentar eliminación cuando el Gateway responde 204
        adapter.respondJson(null, statusCode: 204);
        final retryRemoveOk = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .retry();

        expect(retryRemoveOk, isTrue);
        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isFalse,
        );
      },
    );

    test(
      'Criterio 4: Los favoritos de una sesión no se muestran como propios de otra al cerrar o cambiar sesión',
      () async {
        final adapter = _FavoriteGatewayAdapter()
          ..respondJson({
            'id': newFavoriteUuid,
            'materialId': newMaterialUuid,
            'createdAt': '2026-11-23T14:10:00Z',
            'available': true,
          }, statusCode: 201);

        final container = await createSessionContainer(adapter);
        final subFavs = container.listen(favoritesProvider, (_, _) {});
        final subAction = container.listen(
          favoriteActionProvider(newMaterialUuid),
          (_, _) {},
        );
        addTearDown(() {
          subAction.close();
          subFavs.close();
        });

        await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .addFavorite(summary: sampleMaterial);

        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isTrue,
        );

        // Cerrar sesión limpia el estado confirmado inmediatamente
        await container.read(sessionControllerProvider).clear();

        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isFalse,
        );
        expect(
          container.read(favoritesProvider).items,
          isEmpty,
        );
      },
    );

    testWidgets(
      'Criterio 2 y 3: MaterialSummaryCard y MaterialDetailScreen reflejan de forma coherente el estado confirmado y el reintento',
      (WidgetTester tester) async {
        final adapter = _FavoriteGatewayAdapter()
          ..respondJson({
            'statusCode': 503,
            'code': 'DEPENDENCY_UNAVAILABLE',
            'message': 'Servicio temporalmente caído.',
          }, statusCode: 503);

        final container = await createSessionContainer(adapter);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    MaterialSummaryCard(material: sampleMaterial),
                    Expanded(
                      child: MaterialDetailScreen(
                        detail: MaterialDetail(summary: sampleMaterial),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inicialmente tanto tarjeta como detalle muestran estado no guardado
        expect(find.text('Guardar en favoritos'), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_border_rounded), findsNWidgets(2));

        // Tocar guardar en detalle cuando el servidor falla con 503
        final detailToggle = find.byKey(
          const ValueKey('favorite-toggle-detail-$newMaterialUuid'),
        );
        await tester.ensureVisible(detailToggle);
        await tester.pumpAndSettle();
        await tester.tap(detailToggle);
        await tester.pumpAndSettle();

        // Permanece no guardado y muestra opción de reintentar
        expect(find.text('Guardar en favoritos'), findsOneWidget);
        final detailRetry = find.byKey(
          const ValueKey('favorite-retry-detail-$newMaterialUuid'),
        );
        expect(detailRetry, findsOneWidget);

        // El servidor responde 201 al reintentar
        adapter.respondJson({
          'id': newFavoriteUuid,
          'materialId': newMaterialUuid,
          'createdAt': '2026-11-23T14:15:00Z',
          'available': true,
        }, statusCode: 201);

        await tester.ensureVisible(detailRetry);
        await tester.pumpAndSettle();
        await tester.tap(detailRetry);
        await tester.pumpAndSettle();

        // Tanto tarjeta como detalle reflejan el estado confirmado "Guardado en favoritos"
        expect(find.text('Guardado en favoritos'), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_rounded), findsNWidgets(2));

        // Tocar el ícono en la tarjeta para quitar de favoritos
        adapter.respondJson(null, statusCode: 204);
        await tester.tap(
          find.byKey(
            const ValueKey('favorite-toggle-compact-$newMaterialUuid'),
          ),
        );
        await tester.pumpAndSettle();

        // Tanto tarjeta como detalle vuelven a reflejar "Guardar en favoritos"
        expect(find.text('Guardar en favoritos'), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_border_rounded), findsNWidgets(2));

        await container.read(sessionControllerProvider).clear();
      },
    );

    test(
      'Regresión concurrencia: Confirmar el favorito A NO cancela una petición pendiente del material B',
      () async {
        const materialAUuid = '11111111-1111-4111-8111-111111111111';
        const materialBUuid = '22222222-2222-4222-8222-222222222222';
        const favAUuid = 'aaaaaaaa-1111-4111-8111-111111111111';
        const favBUuid = 'bbbbbbbb-2222-4222-8222-222222222222';

        final completerA = Completer<ResponseBody>();
        final completerB = Completer<ResponseBody>();

        final adapter = _FavoriteGatewayAdapter()
          ..handler = (options) {
            if (options.path.contains(materialAUuid)) {
              return completerA.future;
            }
            if (options.path.contains(materialBUuid)) {
              return completerB.future;
            }
            throw StateError('Ruta inesperada: ${options.path}');
          };

        final container = await createSessionContainer(adapter);
        final subFavs = container.listen(favoritesProvider, (_, _) {});
        final subA = container.listen(
          favoriteActionProvider(materialAUuid),
          (_, _) {},
        );
        final subB = container.listen(
          favoriteActionProvider(materialBUuid),
          (_, _) {},
        );
        addTearDown(() {
          subA.close();
          subB.close();
          subFavs.close();
        });

        // Iniciar ambas peticiones en paralelo (A y B quedan pendientes)
        final futureA = container
            .read(favoriteActionProvider(materialAUuid).notifier)
            .addFavorite();
        final futureB = container
            .read(favoriteActionProvider(materialBUuid).notifier)
            .addFavorite();

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(favoriteActionProvider(materialAUuid)).isPending,
          isTrue,
        );
        expect(
          container.read(favoriteActionProvider(materialBUuid)).isPending,
          isTrue,
        );

        // 1. Se confirma el favorito A primero
        completerA.complete(
          ResponseBody.fromString(
            jsonEncode({
              'id': favAUuid,
              'materialId': materialAUuid,
              'createdAt': '2026-11-26T15:00:00Z',
              'available': true,
            }),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );

        expect(await futureA, isTrue);
        expect(
          container.read(favoriteActionProvider(materialAUuid)).isFavorite,
          isTrue,
        );

        // El material B sigue pendiente y NO fue cancelado por la confirmación de A
        expect(
          container.read(favoriteActionProvider(materialBUuid)).isPending,
          isTrue,
        );
        expect(
          container.read(favoriteActionProvider(materialBUuid)).hasError,
          isFalse,
        );

        // 2. Ahora se confirma el favorito B y termina exitosamente
        completerB.complete(
          ResponseBody.fromString(
            jsonEncode({
              'id': favBUuid,
              'materialId': materialBUuid,
              'createdAt': '2026-11-26T15:00:01Z',
              'available': true,
            }),
            201,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );

        expect(await futureB, isTrue);
        expect(
          container.read(favoriteActionProvider(materialBUuid)).isFavorite,
          isTrue,
        );
        expect(
          container.read(favoritesProvider).containsMaterial(materialAUuid),
          isTrue,
        );
        expect(
          container.read(favoritesProvider).containsMaterial(materialBUuid),
          isTrue,
        );
      },
    );

    test(
      'Regresión refresh: Refrescar el listado conserva los favoritos confirmados y su marca activa',
      () async {
        final adapter = _FavoriteGatewayAdapter()
          ..respondJson({
            'id': newFavoriteUuid,
            'materialId': newMaterialUuid,
            'createdAt': '2026-11-26T15:10:00Z',
            'available': true,
          }, statusCode: 201);

        final container = await createSessionContainer(adapter);
        final subFavs = container.listen(favoritesProvider, (_, _) {});
        final subAction = container.listen(
          favoriteActionProvider(newMaterialUuid),
          (_, _) {},
        );
        addTearDown(() {
          subAction.close();
          subFavs.close();
        });

        // Confirmar un favorito nuevo que no estaba en los fixtures iniciales
        final added = await container
            .read(favoriteActionProvider(newMaterialUuid).notifier)
            .addFavorite(summary: sampleMaterial);
        expect(added, isTrue);
        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isTrue,
        );
        expect(
          container.read(favoritesProvider).containsMaterial(newMaterialUuid),
          isTrue,
        );

        // Refrescar el listado (pull-to-refresh / loadFavorites)
        await container.read(favoritesProvider.notifier).refresh();

        // El favorito confirmado sigue en el listado y conserva su marca isFavorite: true
        expect(
          container.read(favoritesProvider).containsMaterial(newMaterialUuid),
          isTrue,
        );
        expect(
          container.read(favoriteActionProvider(newMaterialUuid)).isFavorite,
          isTrue,
        );
      },
    );
  });
}
