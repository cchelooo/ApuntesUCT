import 'package:flutter/material.dart';

/// Banner de error para formularios.
///
/// Muestra los errores que vienen de la API (credenciales inválidas, correo ya
/// registrado, servidor caído). Se prefiere sobre un `SnackBar` porque el
/// mensaje permanece visible mientras el usuario corrige el formulario, en vez
/// de desaparecer a los pocos segundos.
///
/// Cuando [message] es `null` el widget ocupa cero espacio, de modo que la
/// pantalla no reserve un hueco vacío.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
