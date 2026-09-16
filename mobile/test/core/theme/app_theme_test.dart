import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/core/theme/uct_palette.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';

void main() {
  group('AppTheme', () {
    test('el modo oscuro usa carbón y conserva los acentos UCT', () {
      final theme = AppTheme.oscuro;
      final colors = theme.colorScheme;

      expect(theme.brightness, Brightness.dark);
      expect(colors.surface, UctPalette.fondoOscuro);
      expect(colors.surface, isNot(UctPalette.navy));
      expect(colors.surfaceContainerLow, UctPalette.superficieOscura);
      expect(
        colors.surfaceContainerHighest,
        UctPalette.superficieElevadaOscura,
      );
      expect(colors.primary, UctPalette.amarillo);
      expect(colors.secondary, UctPalette.celeste);
      expect(colors.tertiary, UctPalette.azul);
    });

    test('los textos principales y secundarios mantienen contraste AA', () {
      final colors = AppTheme.oscuro.colorScheme;

      expect(_contrast(colors.onSurface, colors.surface), greaterThan(7));
      expect(
        _contrast(colors.onSurfaceVariant, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.secondary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('define una escala tipográfica base para pantallas nuevas', () {
      final textTheme = AppTheme.claro.textTheme;

      expect(textTheme.displaySmall?.fontSize, 36);
      expect(textTheme.headlineMedium?.fontSize, 32);
      expect(textTheme.titleMedium?.fontWeight, FontWeight.w700);
      expect(textTheme.bodyLarge?.fontSize, 16);
      expect(textTheme.bodyMedium?.fontSize, 14);
      expect(textTheme.labelSmall?.letterSpacing, 0.5);
    });

    test('los componentes base heredan colores y formas del tema', () {
      final theme = AppTheme.oscuro;
      final colors = theme.colorScheme;

      expect(theme.cardTheme.color, colors.surfaceContainerLow);
      expect(theme.cardTheme.elevation, 0);
      expect(
        theme.snackBarTheme.backgroundColor,
        colors.surfaceContainerHighest,
      );
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(
        theme.navigationBarTheme.backgroundColor,
        colors.surfaceContainerLow,
      );
    });

    test('botones y campos conservan su forma entre temas', () {
      final lightButton = AppTheme.claro.filledButtonTheme.style?.shape
          ?.resolve({});
      final darkButton = AppTheme.oscuro.filledButtonTheme.style?.shape
          ?.resolve({});
      final lightOutlined = AppTheme.claro.outlinedButtonTheme.style?.shape
          ?.resolve({});
      final darkOutlined = AppTheme.oscuro.outlinedButtonTheme.style?.shape
          ?.resolve({});
      final lightField = AppTheme.claro.inputDecorationTheme.border;
      final darkField = AppTheme.oscuro.inputDecorationTheme.border;

      expect(lightButton, isA<RoundedRectangleBorder>());
      expect(darkButton, lightButton);
      expect(lightOutlined, lightButton);
      expect(darkOutlined, lightButton);
      expect(lightField, isA<OutlineInputBorder>());
      expect(darkField, isA<OutlineInputBorder>());
      expect(
        (lightField! as OutlineInputBorder).borderRadius,
        (darkField! as OutlineInputBorder).borderRadius,
      );
    });

    testWidgets('el login no se mueve al cambiar sólo los colores', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final light = await _measureLogin(tester, ThemeMode.light);
      final dark = await _measureLogin(tester, ThemeMode.dark);

      expect(dark.title, light.title);
      expect(dark.firstField, light.firstField);
      expect(dark.button, light.button);
    });
  });
}

Future<({Rect title, Rect firstField, Rect button})> _measureLogin(
  WidgetTester tester,
  ThemeMode themeMode,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.claro,
        darkTheme: AppTheme.oscuro,
        themeMode: themeMode,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (
    title: tester.getRect(find.text('Iniciar sesión')),
    firstField: tester.getRect(find.byType(TextFormField).first),
    button: tester.getRect(find.byType(FilledButton)),
  );
}

double _contrast(Color foreground, Color background) {
  final lighter = _luminance(foreground) > _luminance(background)
      ? foreground
      : background;
  final darker = lighter == foreground ? background : foreground;

  return (_luminance(lighter) + 0.05) / (_luminance(darker) + 0.05);
}

double _luminance(Color color) => color.computeLuminance();
