import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';
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
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final loginFields = find.byType(TextFormField);
    await tester.enterText(loginFields.at(0), 'msantana');
    await tester.enterText(loginFields.at(1), 'Password1');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Búsqueda pendiente'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Guardados'));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca pendiente'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
