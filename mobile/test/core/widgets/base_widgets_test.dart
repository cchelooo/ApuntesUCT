import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/core/theme/app_theme.dart';
import 'package:apuntesuct_mobile/core/widgets/widgets.dart';

void main() {
  group('AppButton', () {
    testWidgets('expone variantes consistentes y ejecuta sus acciones', (
      tester,
    ) async {
      var presses = 0;

      await tester.pumpWidget(
        _testApp(
          child: Column(
            children: [
              AppButton.primary(
                label: 'Guardar',
                icon: Icons.save_outlined,
                onPressed: () => presses++,
              ),
              AppButton.secondary(
                label: 'Cancelar',
                onPressed: () => presses++,
              ),
              AppButton.text(label: 'Ver más', onPressed: () => presses++),
            ],
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.tap(find.text('Cancelar'));
      await tester.tap(find.text('Ver más'));

      expect(presses, 3);
    });

    testWidgets('bloquea la acción y anuncia el estado de carga', (
      tester,
    ) async {
      var pressed = false;

      await tester.pumpWidget(
        _testApp(
          child: AppButton.primary(
            label: 'Ingresar',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ingresar'), findsNothing);

      await tester.tap(find.byType(FilledButton));

      expect(pressed, isFalse);
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: 'Ingresar, cargando',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isLiveRegion: true,
        ),
      );
    });

    testWidgets('AppPrimaryButton conserva el contrato de ancho completo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const SizedBox(
            width: 280,
            child: AppPrimaryButton(label: 'Continuar', onPressed: null),
          ),
        ),
      );

      expect(tester.getSize(find.byType(FilledButton)).width, 280);
    });
  });

  group('AppTextField', () {
    testWidgets('reutiliza etiqueta, accesorios, cambios y validación', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      String? latestValue;

      await tester.pumpWidget(
        _testApp(
          child: Form(
            key: formKey,
            child: AppTextField(
              controller: controller,
              label: 'Buscar asignatura',
              hint: 'INF-101',
              icon: Icons.search,
              suffixIcon: const Icon(Icons.tune),
              onChanged: (value) => latestValue = value,
              validator: (value) => value == null || value.isEmpty
                  ? 'Ingresa una búsqueda'
                  : null,
            ),
          ),
        ),
      );

      expect(find.text('Buscar asignatura'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Ingresa una búsqueda'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Programación');

      expect(latestValue, 'Programación');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  group('AppCard', () {
    testWidgets('hereda la superficie del tema y permite interacción', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        _testApp(
          themeMode: ThemeMode.dark,
          child: AppCard(
            semanticLabel: 'Asignatura Álgebra',
            onTap: () => tapped = true,
            child: const Text('Álgebra lineal'),
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, isNull);
      expect(find.byType(InkWell), findsOneWidget);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Card), matching: find.byType(Material)),
      );
      expect(material.color, AppTheme.oscuro.cardTheme.color);

      await tester.tap(find.text('Álgebra lineal'));

      expect(tapped, isTrue);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        matchesSemantics(
          label: 'Asignatura Álgebra',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });
}

Widget _testApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: AppTheme.claro,
    darkTheme: AppTheme.oscuro,
    themeMode: themeMode,
    home: Scaffold(body: Center(child: child)),
  );
}
