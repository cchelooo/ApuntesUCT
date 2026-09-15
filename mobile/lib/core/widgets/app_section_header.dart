import 'package:flutter/material.dart';

import 'app_button.dart';

/// Encabezado reutilizable para secciones de contenido.
///
/// Presenta un título y, opcionalmente, una acción con el tamaño táctil y los
/// colores definidos por el tema. Si [onAction] es `null`, la acción queda
/// deshabilitada en vez de aparentar una interacción que no existe.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    super.key,
  }) : assert(
         actionLabel != null || onAction == null,
         'onAction requiere un actionLabel visible.',
       );

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            AppButton.text(
              label: actionLabel!,
              compact: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
