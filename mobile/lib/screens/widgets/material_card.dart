import 'package:flutter/material.dart';

import '../../models/material_card_data.dart';

/// Tarjeta de material reutilizable para las secciones "Material recomendado"
/// y "Mejores calificados del día".
///
/// - Si [data.rating] y [data.downloads] son `null`, la tarjeta solo muestra
///   título y subtítulo (sección "Recomendado").
/// - Si existen, muestra además el badge de calificación y el conteo de
///   descargas (sección "Mejores calificados").
///
/// Ambas variantes incluyen el doblez triangular amarillo (#EAA83A) en la
/// esquina superior derecha, pintado con [CustomPaint].
class MaterialCard extends StatelessWidget {
  const MaterialCard({
    super.key,
    required this.data,
  });

  final MaterialCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF1F6FB2),
                  size: 24,
                ),
                const SizedBox(height: 10),
                // Título
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF16324F),
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
                  style: const TextStyle(
                    color: Color(0xFF6B8099),
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
                    style: const TextStyle(
                      color: Color(0xFF6B8099),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Doblez triangular amarillo en la esquina superior derecha
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(32, 32),
              painter: _CornerFoldPainter(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEAB5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFEAA83A), size: 13),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF7A5200),
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

/// Pinta un triángulo amarillo (#EAA83A) en la esquina superior derecha de
/// la tarjeta, simulando el clásico "doblez de página".
class _CornerFoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEAA83A);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    // Redondea solo la esquina superior izquierda del triángulo
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
