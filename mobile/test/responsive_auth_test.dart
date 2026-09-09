import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';

const _mobileSizes = [
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(412, 915),
  Size(568, 320),
  Size(640, 360),
  Size(667, 375),
  Size(844, 390),
  Size(915, 412),
];

void main() {
  testWidgets('Login y Registro se adaptan a tamaños móviles comunes', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in _mobileSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          _testApp(themeMode: themeMode, child: const LoginScreen()),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Login falló en $size con tema $themeMode',
        );

        await tester.pumpWidget(
          _testApp(themeMode: themeMode, child: const RegisterScreen()),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Registro falló en $size con tema $themeMode',
        );
      }
    }
  });
}

Widget _testApp({required ThemeMode themeMode, required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: themeMode,
      home: child,
    ),
  );
}
