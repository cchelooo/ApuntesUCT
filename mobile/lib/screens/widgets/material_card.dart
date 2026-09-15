import 'package:flutter/material.dart';

import '../../../core/theme/uct_palette.dart';
import '../../models/material_card_data.dart';

/// Tarjeta de material reutilizable para las secciones "Material recomendado"
/// y "Mejores calificados del día".
///
/// Adapta automáticamente colores, superficies y tipografía a [ColorScheme]
/// del tema activo (claro u oscuro).
class MaterialCard extends StatelessWidget {
  const MaterialCard({super.key, required this.data});

  final MaterialCardData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Espacio para no solapar el doblez triangular
                const SizedBox(height: 8),
                // Ícono de documento
                Icon(
                  Icons.description_outlined,
                  color: esOscuro ? colorScheme.secondary : colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(height: 10),
                // Título
                Text(
                  data.title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Subtítulo (profesor o asignatura)
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Badge de rating + descargas (solo cuando están presentes)
                if (data.rating != null) ...[
                  const SizedBox(height: 12),
                  _RatingBadge(rating: data.rating!),
                ],
                if (data.downloads != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${data.downloads} descargas',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Doblez triangular en la esquina superior derecha
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(32, 32),
              painter: const _CornerFoldPainter(color: UctPalette.amarillo),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de calificación
// ---------------------------------------------------------------------------

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esOscuro
            ? UctPalette.amarillo.withValues(alpha: 0.18)
            : const Color(0xFFFCEAB5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: esOscuro ? UctPalette.amarillo : UctPalette.dorado,
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: esOscuro ? colorScheme.onSurface : const Color(0xFF7A5200),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter del doblez triangular
// ---------------------------------------------------------------------------

/// Pinta un triángulo amarillo en la esquina superior derecha de la tarjeta.
class _CornerFoldPainter extends CustomPainter {
  const _CornerFoldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    // Redondea solo la esquina superior derecha
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topRight: const Radius.circular(16),
      ),
      paint,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerFoldPainter oldDelegate) =>
      oldDelegate.color != color;
}
