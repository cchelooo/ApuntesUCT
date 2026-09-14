import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_mode_provider.dart';

/// Botón que alterna entre modo claro y oscuro.
///
/// Muestra el icono de aquello a lo que se va a cambiar, no del estado actual:
/// estando en claro se ve una luna, porque tocarla lleva al modo oscuro. Es la
/// convención de casi todas las apps y evita la duda de "¿esto indica dónde
/// estoy o a dónde voy?".
///
/// La animación es corta a propósito. Cambiar el tema ya repinta la pantalla
/// entera; una transición larga encima se siente lenta.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se lee el brillo efectivo, que en modo automático lo decide el sistema.
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final destino = esOscuro ? 'claro' : 'oscuro';

    return IconButton(
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .alternar(esOscuro ? Brightness.dark : Brightness.light),
      tooltip: 'Cambiar a modo $destino',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          // La clave hace que AnimatedSwitcher note el cambio: sin ella ve el
          // mismo tipo de widget y no anima nada.
          key: ValueKey(esOscuro),
          size: 22,
        ),
      ),
    );
  }
}
