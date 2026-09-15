import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/main.dart';
import 'package:apuntesuct_mobile/providers/theme_mode_provider.dart';
import 'package:apuntesuct_mobile/screens/home_screen.dart';

void main() {
  group('HomeScreen Tests', () {
    testWidgets(
      'renderiza correctamente en modo claro y oscuro sin excepciones',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                themeModeProvider.overrideWith(
                  () => _ThemeController(themeMode),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.claro,
                darkTheme: AppTheme.oscuro,
                themeMode: themeMode,
                home: const HomeScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.text('ApuntesUCT'), findsOneWidget);
          expect(find.text('Inicio'), findsNWidgets(2)); // Header y tab
          expect(find.text('Tus cursos'), findsOneWidget);
          expect(find.text('Material recomendado'), findsOneWidget);
          expect(find.text('Mejores calificados del día'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'navegación en los tabs inferiores lleva a las rutas correspondientes',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          appRouter.go('/login');
        });

        appRouter.go('/');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWith(
                (ref) =>
                    const MockAuthRepository(simulatedDelay: Duration.zero),
              ),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        // 1. Tab Buscar -> /search
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Búsqueda pendiente'), findsOneWidget);

        // Volver a Home
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);

        // 2. Tab Guardados -> /library
        await tester.tap(find.byIcon(Icons.bookmark_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Biblioteca pendiente'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);

        // 3. Tab Perfil -> /profile
        await tester.tap(find.byIcon(Icons.person_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Perfil pendiente'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets('acciones de sección navegan a catálogo y búsqueda', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        appRouter.go('/login');
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => const MockAuthRepository(simulatedDelay: Duration.zero),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      // "Ver todos" -> Catálogo
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo pendiente'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // "Más" -> Catálogo
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo pendiente'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // "Ranking" -> Búsqueda
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('Búsqueda pendiente'), findsOneWidget);
    });

    testWidgets('botón de cerrar sesión desconecta al usuario y va a /login', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        appRouter.go('/login');
      });

      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => const MockAuthRepository(simulatedDelay: Duration.zero),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Tap en botón cerrar sesión del AppBar
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      // Debe redirigir a LoginScreen
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}

class _ThemeController extends ThemeModeNotifier {
  _ThemeController(this._initial);
  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;
}
