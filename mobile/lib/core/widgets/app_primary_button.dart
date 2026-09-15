import 'package:flutter/material.dart';

import 'app_button.dart';

/// Botón principal de un formulario, con estado de carga integrado.
///
/// Mientras [isLoading] es `true` el botón queda deshabilitado y muestra un
/// indicador de progreso. Eso evita el doble envío: sin este bloqueo, dos
/// toques rápidos en "Ingresar" disparaban dos peticiones de login.
///
/// El indicador reemplaza al texto conservando el alto del botón, para que la
/// pantalla no salte al iniciar la petición.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton.primary(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      compact: compact,
      fullWidth: true,
      icon: icon,
    );
  }
}
