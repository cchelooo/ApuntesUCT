import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier que maneja el estado de autenticación básico como ejemplo inicial.
/// Extiende `Notifier<bool>` de acuerdo con la API moderna de Riverpod 3.x.
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    // false = no autenticado por defecto
    return false;
  }

  /// Cambia el estado a autenticado
  void login() {
    state = true;
  }

  /// Cambia el estado a no autenticado
  void logout() {
    state = false;
  }

  /// Alterna el estado de autenticación (utilidad para demos y pruebas)
  void toggle() {
    state = !state;
  }
}

/// Provider global para AuthNotifier
final authProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
