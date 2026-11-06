import 'package:flutter/material.dart';

class MaterialRatingControl extends StatelessWidget {
  final int? rating; // Valor actual de 1 a 5, o null si no hay selección
  final bool isEnabled; // Para distinguir si la acción está disponible
  final bool isSubmitting; // Para el estado de envío (cargando)
  final ValueChanged<int>? onRatingSelected; // Callback al seleccionar

  const MaterialRatingControl({
    super.key,
    this.rating,
    this.isEnabled = true,
    this.isSubmitting = false,
    this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final disabledColor = theme.disabledColor;

    return Semantics(
      container: true,
      label: 'Control de calificación. Escala de 1 a 5 estrellas.',
      value: rating != null ? '$rating de 5 estrellas' : 'Sin calificar',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final isSelected = rating != null && starValue <= rating!;

          return IconButton(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              size: 32,
            ),
            color: isEnabled
                ? (isSelected ? activeColor : theme.iconTheme.color)
                : disabledColor,
            tooltip: '$starValue estrellas',
            onPressed: (isEnabled && !isSubmitting)
                ? () => onRatingSelected?.call(starValue)
                : null,
          );
        }),
      ),
    );
  }
}