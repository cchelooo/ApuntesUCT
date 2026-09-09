import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/uct_palette.dart';
import '../validation/validators.dart';
import 'app_text_field.dart';

/// Campo de correo institucional en el que el usuario escribe **sólo su nombre
/// de usuario**: el dominio lo pone la app y no se puede editar.
///
/// El controlador guarda únicamente la parte anterior al arroba. El dominio no
/// existe como texto editable en ningún momento, así que no hay forma de
/// alterarlo: ni escribiendo, ni pegando, ni con autocompletado.
///
/// El dominio se deduce del nombre de usuario según la convención de la
/// universidad (ver `Validators.institutionalDomainFor`):
///
/// ```text
/// jperez      →  jperez@uct.cl
/// jperez2020  →  jperez2020@alu.uct.cl
/// ```
///
/// Para obtener el correo completo al enviar el formulario:
///
/// ```dart
/// final email = Validators.composeInstitutionalEmail(controller.text);
/// ```
class InstitutionalEmailField extends StatefulWidget {
  const InstitutionalEmailField({
    required this.controller,
    this.label = 'Correo institucional',
    this.hint = 'jperez2020',
    this.enabled = true,
    this.compact = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    super.key,
  });

  /// Controlador del **nombre de usuario**, no del correo completo.
  final TextEditingController controller;

  final String label;
  final String? hint;
  final bool enabled;
  final bool compact;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  State<InstitutionalEmailField> createState() =>
      _InstitutionalEmailFieldState();
}

class _InstitutionalEmailFieldState extends State<InstitutionalEmailField> {
  late String _domain;

  @override
  void initState() {
    super.initState();
    _domain = Validators.institutionalDomainFor(widget.controller.text);
    widget.controller.addListener(_syncDomain);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDomain);
    super.dispose();
  }

  /// Recalcula el dominio mientras el usuario escribe.
  ///
  /// Sólo reconstruye cuando el dominio efectivamente cambió: en la mayoría de
  /// las pulsaciones el sufijo es el mismo y no hay nada que repintar.
  void _syncDomain() {
    final domain = Validators.institutionalDomainFor(widget.controller.text);
    if (domain != _domain) {
      setState(() => _domain = domain);
    }
  }

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
          keyboardType: TextInputType.emailAddress,
          textInputAction: widget.textInputAction,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.username],
          onFieldSubmitted: widget.onFieldSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          inputFormatters: [_LocalPartInputFormatter()],
          style: TextStyle(
            fontSize: widget.compact ? 14 : 15.5,
            fontWeight: esOscuro ? FontWeight.w500 : FontWeight.w600,
          ),
          validator: (value) {
            final error = Validators.emailLocalPart(value);
            if (error != null) return error;

            // El dominio lo pone la app, pero igual se valida el correo completo:
            // si mañana cambia la regla de dominios, el fallo aparece acá y no
            // recién cuando el backend rechace el registro.
            return Validators.institutionalEmail(
              Validators.composeInstitutionalEmail(value),
            );
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.compact ? 8 : (esOscuro ? 13 : 15),
            ),
            suffix: Text(
              '@$_domain',
              style: TextStyle(
                color: esOscuro
                    ? UctPalette.textoCampoOscuro
                    : UctPalette.textoCampoClaro,
                fontSize: widget.compact ? 14 : 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mantiene en el campo únicamente un nombre de usuario válido.
///
/// - pasa todo a minúsculas, porque el correo se envía normalizado;
/// - descarta espacios;
/// - **corta en el arroba**: si alguien escribe o pega `jperez@gmail.com`,
///   queda `jperez` y el dominio lo sigue decidiendo la app.
///
/// Cortar en vez de rechazar es lo que hace que pegar un correo completo o
/// aceptar el autocompletado del sistema funcione en lugar de dejar basura.
class _LocalPartInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toLowerCase().replaceAll(RegExp(r'\s'), '');

    final atIndex = text.indexOf('@');
    if (atIndex >= 0) {
      text = text.substring(0, atIndex);
    }

    if (text == newValue.text) return newValue;

    // Al acortar el texto hay que reubicar el cursor, o Flutter lanza por una
    // selección fuera de rango.
    final offset = math.max(
      0,
      math.min(newValue.selection.baseOffset, text.length),
    );

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}
