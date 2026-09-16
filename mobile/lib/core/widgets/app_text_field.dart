import 'package:flutter/material.dart';

/// Etiqueta externa de los campos de autenticación.
///
/// La maqueta usa etiquetas sobre el control, no el label flotante por defecto
/// de Material. Su tamaño y capitalización son iguales en ambos temas para que
/// alternar el brillo no cambie la composición del formulario.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel({required this.label, this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontSize: compact ? 11.5 : 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: compact ? 1.15 : null,
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
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.compact = false,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final bool compact;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFieldLabel(label: label, compact: compact),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          readOnly: readOnly,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(
            fontSize: compact ? 14 : 15.5,
            fontWeight: FontWeight.w600,
          ),
          // El error aparece al primer intento de envío y luego se corrige en
          // vivo, en lugar de regañar al usuario mientras todavía está
          // escribiendo.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 6 : 15,
            ),
          ),
        ),
      ],
    );
  }
}
