import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_harness.dart';

final _messageProvider = Provider<String>((ref) => 'mensaje original');

void main() {
  testWidgets('monta widgets con providers sobrescritos', (tester) async {
    await pumpWidgetUnderTest(
      tester,
      child: Consumer(
        builder: (context, ref, child) => Text(ref.watch(_messageProvider)),
      ),
      wrapper: (child) => ProviderScope(
        overrides: [_messageProvider.overrideWithValue('mensaje de prueba')],
        child: child,
      ),
    );

    expect(find.text('mensaje de prueba'), findsOneWidget);
    final context = tester.element(find.text('mensaje de prueba'));
    expect(MediaQuery.sizeOf(context), defaultTestSurfaceSize);
  });

  testWidgets('monta rutas aisladas y permite navegar entre ellas', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/inicio',
      routes: [
        GoRoute(
          path: '/inicio',
          builder: (context, state) => const Scaffold(body: Text('Inicio')),
        ),
        GoRoute(
          path: '/perfil',
          builder: (context, state) => const Scaffold(body: Text('Perfil')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpRouterUnderTest(tester, router: router);
    expect(find.text('Inicio'), findsOneWidget);

    router.go('/perfil');
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
  });
}
