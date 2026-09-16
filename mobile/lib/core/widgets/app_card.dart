import 'package:flutter/material.dart';

/// Superficie contenida reutilizable para agrupar información relacionada.
///
/// Usa el [CardTheme] de la aplicación para mantener colores, borde y forma
/// consistentes en modo claro y oscuro. Cuando recibe [onTap], toda la tarjeta
/// obtiene respuesta táctil y semántica de botón.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    final card = Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (semanticLabel == null) return card;

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(child: card),
    );
  }
}
