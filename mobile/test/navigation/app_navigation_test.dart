import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/home/presentation/home_screen.dart';
import 'package:apuntesuct_mobile/features/profile/presentation/profile_screen.dart';
import 'package:apuntesuct_mobile/main.dart';

void main() {
  testWidgets('recorre autenticación y navegación principal', (tester) async {
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

    expect(find.byType(LoginScreen), findsOneWidget);
    _expectRoute('/login');

    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    _expectRoute('/register');

    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    _expectRoute('/login');

    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), 'msantana');
    await tester.enterText(loginFields.at(1), 'Password1');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    _expectRoute('/');

    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    _expectRoute('/catalog');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    _expectRoute('/');

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Búsqueda pendiente'), findsOneWidget);
    _expectRoute('/search');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    _expectRoute('/');

    await tester.tap(find.text('Guardados'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca pendiente'), findsOneWidget);
    _expectRoute('/library');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    _expectRoute('/');

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    _expectRoute('/profile');

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    _expectRoute('/');

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    _expectRoute('/login');
  });
}

void _expectRoute(String path) {
  expect(appRouter.state.uri.path, path);
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
