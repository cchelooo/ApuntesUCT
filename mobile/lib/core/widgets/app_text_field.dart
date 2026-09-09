import 'package:flutter/material.dart';

import '../theme/uct_palette.dart';

/// Etiqueta externa de los campos de autenticación.
///
/// La maqueta usa etiquetas sobre el control, no el label flotante por defecto
/// de Material. También cambia a mayúsculas y aumenta el espaciado en Navy para
/// conservar la jerarquía visual de esa variante.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Text(
      esOscuro ? label.toUpperCase() : label,
      style: TextStyle(
        color: esOscuro
            ? UctPalette.textoTenueOscuro
            : theme.colorScheme.onSurfaceVariant,
        fontSize: esOscuro ? 11 : 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: esOscuro ? 1.1 : 0,
      ),
    );
  }
}

/// Campo de texto con la decoración estándar de la aplicación.
///
/// Centraliza borde, relleno, icono y comportamiento de teclado para que todos
/// los formularios se vean y se comporten igual. Antes cada pantalla declaraba
/// su propio [InputDecoration] y las diferencias se notaban al alternar entre
/// Login y Registro.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.compact = false,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final bool compact;
  final TextCapitalization textCapitalization;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(
            fontSize: compact ? 14 : 15.5,
            fontWeight: esOscuro ? FontWeight.w500 : FontWeight.w600,
          ),
          // El error aparece al primer intento de envío y luego se corrige en
          // vivo, en lugar de regañar al usuario mientras todavía está
          // escribiendo.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 8 : (esOscuro ? 13 : 15),
            ),
          ),
        ),
      ],
    );
  }
}
