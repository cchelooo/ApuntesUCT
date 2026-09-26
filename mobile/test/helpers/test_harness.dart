import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Tamaño de referencia para probar la interfaz en un teléfono móvil.
const defaultTestSurfaceSize = Size(390, 844);

/// Permite envolver la aplicación de prueba con providers sobrescritos u otros
/// widgets requeridos por cada escenario.
typedef TestAppWrapper = Widget Function(Widget child);

/// Monta una aplicación completa conservando su configuración de Material,
/// Riverpod y rutas.
Future<void> pumpAppUnderTest(
  WidgetTester tester, {
  required Widget app,
  Size surfaceSize = defaultTestSurfaceSize,
}) async {
  _configureSurface(tester, surfaceSize);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Monta un widget dentro de Material y Riverpod con un tamaño reproducible.
Future<void> pumpWidgetUnderTest(
  WidgetTester tester, {
  required Widget child,
  Size surfaceSize = defaultTestSurfaceSize,
  TestAppWrapper? wrapper,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
}) async {
  final app = MaterialApp(
    theme: theme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    home: child,
  );

  await pumpAppUnderTest(
    tester,
    app: _wrapWithScope(app, wrapper),
    surfaceSize: surfaceSize,
  );
}

/// Monta un router para pruebas de navegación sin depender del router global.
Future<void> pumpRouterUnderTest(
  WidgetTester tester, {
  required GoRouter router,
  Size surfaceSize = defaultTestSurfaceSize,
  TestAppWrapper? wrapper,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
}) async {
  final app = MaterialApp.router(
    theme: theme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    routerConfig: router,
  );

  await pumpAppUnderTest(
    tester,
    app: _wrapWithScope(app, wrapper),
    surfaceSize: surfaceSize,
  );
}

Widget _wrapWithScope(Widget app, TestAppWrapper? wrapper) {
  return wrapper?.call(app) ?? ProviderScope(child: app);
}

void _configureSurface(WidgetTester tester, Size surfaceSize) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surfaceSize;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
