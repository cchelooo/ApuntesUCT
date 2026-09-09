import 'package:flutter/material.dart';

import '../theme/uct_palette.dart';
import 'app_text_field.dart';

/// Campo de contraseña con alternador de visibilidad.
///
/// Es un [StatefulWidget] porque la visibilidad del texto es estado puramente
/// visual del campo: no le interesa al resto de la app y no tiene por qué
/// llegar a Riverpod.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.controller,
    required this.label,
    this.hint,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.validator,
    this.enabled = true,
    this.compact = false,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool compact;
  final void Function(String)? onFieldSubmitted;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFieldLabel(label: widget.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscured,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: TextStyle(
            fontSize: widget.compact ? 14 : 15.5,
            fontWeight: esOscuro ? FontWeight.w500 : FontWeight.w600,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.compact ? 8 : (esOscuro ? 13 : 15),
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscured = !_obscured),
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: esOscuro
                    ? UctPalette.textoCampoOscuro
                    : UctPalette.textoCampoClaro,
              ),
              tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: widget.compact ? 40 : 48,
                minHeight: widget.compact ? 40 : 48,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
