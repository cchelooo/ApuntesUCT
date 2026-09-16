import 'package:flutter/material.dart';

import '../../../../core/theme/uct_palette.dart';
import '../../domain/profile_models.dart';

/// Modal bottom sheet para explorar las insignias y logros del usuario en ApuntesUCT.
class BadgesModalSheet extends StatelessWidget {
  const BadgesModalSheet({
    super.key,
    required this.badges,
  });

  final List<ProfileBadge> badges;

  /// Muestra el modal de insignias adaptado al tema actual.
  static Future<void> show(BuildContext context, List<ProfileBadge> badges) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BadgesModalSheet(badges: badges),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final totalCount = badges.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Indicador de arrastre superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: esOscuro
                        ? UctPalette.bordeOscuro
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: esOscuro
                          ? UctPalette.amarillo.withValues(alpha: 0.18)
                          : const Color(0xFFFCF4D8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: esOscuro
                          ? UctPalette.amarillo
                          : const Color(0xFF825F00),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insignias y Logros',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Reconocimientos por aportes en ApuntesUCT',
                          style: TextStyle(
                            color: esOscuro
                                ? UctPalette.textoSuaveOscuro
                                : UctPalette.textoSuaveClaro,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tarjeta de progreso global
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: esOscuro
                      ? UctPalette.superficieElevadaOscura
                      : const Color(0xFFF3F8FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: esOscuro
                        ? UctPalette.bordeOscuro
                        : const Color(0xFFD7E7F3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Progreso de insignias',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$unlockedCount de $totalCount obtenidas',
                          style: TextStyle(
                            color: esOscuro
                                ? UctPalette.amarillo
                                : UctPalette.azul,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: esOscuro
                            ? UctPalette.fondoOscuro
                            : const Color(0xFFDFECF6),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          esOscuro ? UctPalette.amarillo : UctPalette.azul,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lista de insignias
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: badges.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return _BadgeListItem(
                      badge: badge,
                      esOscuro: esOscuro,
                      colorScheme: colorScheme,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeListItem extends StatelessWidget {
  const _BadgeListItem({
    required this.badge,
    required this.esOscuro,
    required this.colorScheme,
  });

  final ProfileBadge badge;
  final bool esOscuro;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;

    final colorFondoItem = esOscuro
        ? (isUnlocked
            ? UctPalette.superficieElevadaOscura
            : UctPalette.superficieOscura)
        : (isUnlocked ? Colors.white : const Color(0xFFF7FAFD));

    final colorBordeItem = esOscuro
        ? (isUnlocked ? UctPalette.bordeOscuro : Colors.transparent)
        : (isUnlocked ? const Color(0xFFE4EDF5) : const Color(0xFFEFF4F9));

    final colorFondoIcono = isUnlocked
        ? (esOscuro
            ? UctPalette.amarillo.withValues(alpha: 0.2)
            : const Color(0xFFFCF3D7))
        : (esOscuro
            ? UctPalette.fondoOscuro
            : const Color(0xFFEBF1F7));

    final colorIcono = isUnlocked
        ? (esOscuro ? UctPalette.amarillo : const Color(0xFFB8860B))
        : (esOscuro ? UctPalette.textoTenueOscuro : Colors.grey.shade400);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorFondoItem,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBordeItem),
        boxShadow: isUnlocked && !esOscuro
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono distintivo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorFondoIcono,
              borderRadius: BorderRadius.circular(14),
              border: isUnlocked
                  ? Border.all(
                      color: esOscuro
                          ? UctPalette.amarillo.withValues(alpha: 0.4)
                          : const Color(0xFFF3DE97),
                    )
                  : null,
            ),
            child: Icon(
              badge.icon,
              color: colorIcono,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Información de la insignia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badge.title,
                        style: TextStyle(
                          color: isUnlocked
                              ? colorScheme.onSurface
                              : (esOscuro
                                  ? UctPalette.textoSuaveOscuro
                                  : UctPalette.textoSuaveClaro),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: esOscuro
                              ? const Color(0xFF1E3A24)
                              : const Color(0xFFE6F6ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: esOscuro
                                  ? const Color(0xFF5CD685)
                                  : const Color(0xFF1F9254),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Obtenida',
                              style: TextStyle(
                                color: esOscuro
                                    ? const Color(0xFF5CD685)
                                    : const Color(0xFF1F9254),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: TextStyle(
                    color: esOscuro
                        ? UctPalette.textoSuaveOscuro
                        : UctPalette.textoSuaveClaro,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: badge.maxProgress > 0
                                ? badge.currentProgress / badge.maxProgress
                                : 0,
                            minHeight: 5,
                            backgroundColor: esOscuro
                                ? UctPalette.fondoOscuro
                                : const Color(0xFFDFECF6),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              esOscuro
                                  ? UctPalette.celeste
                                  : UctPalette.azul,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${badge.currentProgress}/${badge.maxProgress}',
                        style: TextStyle(
                          color: esOscuro
                              ? UctPalette.textoTenueOscuro
                              : UctPalette.textoSuaveClaro,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
