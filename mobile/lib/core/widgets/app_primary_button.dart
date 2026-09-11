import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: compact
            ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))
            : null,
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
