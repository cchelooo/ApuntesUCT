import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/features/profile/presentation/profile_screen.dart';
import 'package:apuntesuct_mobile/providers/theme_mode_provider.dart';

void main() {
  group('ProfileScreen Tests', () {
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
                  () => _ThemeTestController(themeMode),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.claro,
                darkTheme: AppTheme.oscuro,
                themeMode: themeMode,
                home: const ProfileScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Verifica la presencia de la pantalla y el título
          expect(find.byType(ProfileScreen), findsOneWidget);
          expect(find.text('Perfil'), findsNWidgets(2)); // AppBar y BottomNav

          // Verifica datos del usuario de la maqueta
          expect(find.text('Marcelo Santana'), findsOneWidget);
          expect(find.text('8'), findsOneWidget);
          expect(find.text('subidos'), findsOneWidget);
          expect(find.text('42'), findsOneWidget);
          expect(find.text('guardados'), findsOneWidget);
          expect(find.text('4.8'), findsOneWidget);
          expect(find.text('reputación'), findsOneWidget);

          // Verifica botones de acción
          expect(find.text('Editar perfil'), findsOneWidget);
          expect(find.text('Ver insignias'), findsOneWidget);
          expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);

          // Verifica sección de cursos
          expect(find.text('Cursos'), findsNWidgets(2)); // Sección y Tab
          expect(find.text('Semestre 2'), findsOneWidget);

          // No debe haber excepciones de layout ni desbordamientos
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'muestra la cuadrícula de materiales subidos y permite alternar a la pestaña cursos',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.claro,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pestaña inicial: Material subido
        expect(find.text('Material subido'), findsOneWidget);
        expect(find.text('Guía API REST'), findsOneWidget);
        expect(find.text('Resumen\nmicroservicios'), findsOneWidget);
        expect(find.text('Checklist\nSwagger'), findsOneWidget);

        // Tap en pestaña "Cursos" dentro del TabBar del perfil
        final tabCursos = find.text('Cursos').last;
        await tester.tap(tabCursos);
        await tester.pumpAndSettle();

        // Al cambiar de pestaña, se listan los cursos detallados
        expect(find.text('Arquitectura de Software'), findsOneWidget);
        expect(find.text('Ingeniería de Software'), findsOneWidget);
        expect(find.text('Bases de Datos'), findsOneWidget);

        // Volver a la pestaña de materiales
        await tester.tap(find.text('Material subido'));
        await tester.pumpAndSettle();
        expect(find.text('Guía API REST'), findsOneWidget);
      },
    );

    testWidgets(
      'botón de ajustes abre el menú inferior de cuenta y configuración',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.claro,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap en el botón de ajustes (engranaje)
        await tester.tap(find.byTooltip('Ajustes'));
        await tester.pumpAndSettle();

        // Debe abrirse el BottomSheet
        expect(find.text('Ajustes y Cuenta'), findsOneWidget);
        expect(find.text('Acerca de ApuntesUCT'), findsOneWidget);
        expect(find.text('Cerrar sesión'), findsOneWidget);
      },
    );

    testWidgets(
      'botón QR abre diálogo informativo con código QR',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.claro,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap en el botón QR
        await tester.tap(find.byIcon(Icons.qr_code_2_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Código QR de Perfil'), findsOneWidget);
        expect(find.text('Cerrar'), findsOneWidget);

        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();

        expect(find.text('Código QR de Perfil'), findsNothing);
      },
    );

    testWidgets(
      'botón Editar perfil abre modal, permite cambiar nombre/bio y actualiza el perfil reactivamente',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.claro,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verificar nombre original
        expect(find.text('Marcelo Santana'), findsOneWidget);

        // Tap en "Editar perfil"
        await tester.tap(find.text('Editar perfil'));
        await tester.pumpAndSettle();

        // Modal de edición abierto
        expect(find.text('Editar Perfil'), findsOneWidget);
        expect(find.text('Nombre completo'), findsOneWidget);
        expect(find.text('Carrera o programa'), findsOneWidget);
        expect(find.text('Guardar cambios'), findsOneWidget);

        // Modificar el nombre
        final nameField = find.widgetWithText(TextFormField, 'Marcelo Santana');
        await tester.enterText(nameField, 'Nelson Muñoz');
        await tester.pumpAndSettle();

        // Guardar cambios
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        // Verificar que el modal se cerró y el nuevo nombre se visualiza en la cabecera
        expect(find.text('Editar Perfil'), findsNothing);
        expect(find.text('Nelson Muñoz'), findsOneWidget);
        expect(find.text('Perfil actualizado correctamente'), findsOneWidget);
      },
    );

    testWidgets(
      'botón Ver insignias abre modal con logros, progreso y lista de insignias',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.claro,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap en "Ver insignias"
        await tester.tap(find.text('Ver insignias'));
        await tester.pumpAndSettle();

        // Modal de insignias abierto
        expect(find.text('Insignias y Logros'), findsOneWidget);
        expect(find.text('Progreso de insignias'), findsOneWidget);
        expect(find.text('Colaborador Destacado'), findsOneWidget);
        expect(find.text('Top Calificado'), findsOneWidget);
        expect(find.text('Coleccionista'), findsOneWidget);

        // Cerrar modal
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        expect(find.text('Insignias y Logros'), findsNothing);
      },
    );
  });
}

class _ThemeTestController extends ThemeModeNotifier {
  _ThemeTestController(this._initial);
  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;
}
