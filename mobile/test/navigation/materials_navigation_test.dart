import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/home/presentation/home_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/main.dart';

void main() {
  testWidgets('issue #279: rutas del módulo materiales sin pantalla en blanco',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      appRouter.go('/login');
    });

    appRouter.go('/login');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith(
            (ref) => const MockAuthRepository(simulatedDelay: Duration.zero),
          ),
          catalogRepositoryProvider.overrideWithValue(
            const _FakeCatalogRepository(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // --- Apertura directa: listado ---
    appRouter.go('/materials');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDiscoveryScreen), findsOneWidget);
    expect(find.text('Descubrir Materiales'), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials');

    // --- Apertura directa: subida (placeholder de #280, nunca en blanco) ---
    appRouter.go('/materials/upload');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialUploadScreen), findsOneWidget);
    expect(find.text('Subir Material'), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials/upload');

    // --- Apertura directa: detalle por ID conocido ---
    appRouter.go('/materials/mat-101');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDetailScreen), findsOneWidget);
    expect(find.text('Detalle del Material'), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials/mat-101');

    // --- Apertura directa: ID desconocido no revienta ni queda en blanco ---
    appRouter.go('/materials/id-inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Material no encontrado'), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials/id-inexistente');

    // --- El catálogo académico sigue intacto ---
    appRouter.go('/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);

    // --- Home accede al módulo (botones + bottom nav) ---
    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Explorar materiales'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDiscoveryScreen), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Subir material'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialUploadScreen), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials/upload');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Materiales'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDiscoveryScreen), findsOneWidget);
    expect(appRouter.state.uri.path, '/materials');
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  const _FakeCatalogRepository();

  @override
  Future<List<CatalogItem>> getCatalog({String? search}) async {
    return const [
      CatalogItem(
        id: 'calculo-i',
        title: 'Cálculo I',
        author: 'Universidad Católica de Temuco',
        subject: 'Ingeniería Civil Informática',
      ),
    ];
  }
}
