import 'package:flutter/material.dart';

import '../../state/home_state.dart';

/// Paleta de fondos para las tarjetas de curso (se rota cíclicamente).
const _kCardColors = [
  Color(0xFF1F6FB2), // Azul
  Color(0xFFEAA83A), // Amarillo/mostaza
  Color(0xFF2F8F73), // Verde
];

/// Colores de texto correspondientes a cada fondo de [_kCardColors].
/// El amarillo necesita texto oscuro para cumplir con contraste WCAG AA.
const _kTextColors = [
  Colors.white,
  Color(0xFF16324F), // Texto oscuro sobre fondo amarillo
  Colors.white,
];

/// Tarjeta de curso que forma la lista horizontal de "Tus cursos".
///
/// Muestra el nombre del curso y la cantidad de apuntes disponibles.
/// El color de fondo rota cíclicamente según el [index] de la tarjeta.
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.entry,
    required this.index,
  });

  final CourseEntry entry;

  /// Posición de la tarjeta en la lista (determina el color de fondo).
  final int index;

  @override
  Widget build(BuildContext context) {
    final bgColor = _kCardColors[index % _kCardColors.length];
    final textColor = _kTextColors[index % _kTextColors.length];

    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ícono de libro decorativo
          Icon(Icons.menu_book_rounded, color: textColor.withValues(alpha: 0.7), size: 26),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  entry.subject.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.materialCount} apuntes',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
