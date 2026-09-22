import 'package:flutter/material.dart';

import 'package:apuntesuct_mobile/core/theme/uct_palette.dart';

import '../providers/home_provider.dart';

/// Paleta de fondos para las tarjetas de curso en modo claro.
const _kLightCardColors = [
  UctPalette.azul,
  UctPalette.dorado,
  UctPalette.verde,
];

/// Colores de texto correspondientes en modo claro (WCAG AA).
const _kLightTextColors = [Colors.white, UctPalette.navy, Colors.white];

/// Paleta de fondos para las tarjetas de curso en modo oscuro.
const _kDarkCardColors = [
  UctPalette.azulTarjetaOscura,
  UctPalette.doradoOscuro,
  UctPalette.verdeOscuro,
];

/// Colores de texto correspondientes en modo oscuro.
const _kDarkTextColors = [
  UctPalette.textoPrincipalOscuro,
  UctPalette.textoPrincipalOscuro,
  UctPalette.textoPrincipalOscuro,
];

/// Tarjeta de curso que forma la lista horizontal de "Tus cursos".
///
/// Muestra el nombre del curso y la cantidad de apuntes disponibles.
/// El color de fondo rota cíclicamente según el [index] de la tarjeta.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.entry, required this.index});

  final CourseEntry entry;

  /// Posición de la tarjeta en la lista (determina el color de fondo).
  final int index;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final cardColors = esOscuro ? _kDarkCardColors : _kLightCardColors;
    final textColors = esOscuro ? _kDarkTextColors : _kLightTextColors;

    final bgColor = cardColors[index % cardColors.length];
    final textColor = textColors[index % textColors.length];

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
          Icon(
            Icons.menu_book_rounded,
            color: textColor.withValues(alpha: 0.7),
            size: 26,
          ),
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
