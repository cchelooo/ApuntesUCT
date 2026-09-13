import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controla si la app se ve en modo claro u oscuro.
///
/// Arranca en [ThemeMode.system]: la decisión la toma el sistema operativo, que
/// es quien sabe si el usuario tiene el modo noche activado o programado por
/// horario. Flutter lo entrega en `MediaQuery.platformBrightness` y reconstruye
/// la app sola cuando cambia.
///
/// El botón de la pantalla de acceso permite forzarlo. Al hacerlo se abandona el
/// modo automático: a partir de ahí manda la elección del usuario, que es lo que
/// se espera de un interruptor.
///
/// La elección vive en memoria. Al cerrar la app se vuelve a seguir al sistema;
/// persistirla es trabajo del Sprint 2, junto con el resto de las preferencias.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Alterna entre claro y oscuro.
  ///
  /// Recibe el brillo que se está viendo, no el [ThemeMode] guardado, porque en
  /// modo automático el valor guardado es `system` y no dice nada sobre lo que
  /// hay en pantalla. Sin este dato, el primer toque tendría que adivinar.
  void alternar(Brightness brilloActual) {
    state = brilloActual == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Vuelve a seguir la preferencia del sistema.
  void seguirAlSistema() => state = ThemeMode.system;
}

/// Provider global del modo de tema.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
