import 'package:flutter/material.dart';

import '../../../../core/theme/uct_palette.dart';
import '../../domain/profile_models.dart';
import 'badges_modal_sheet.dart';
import 'edit_profile_sheet.dart';

/// Tarjeta principal de información del usuario en el perfil.
/// Incluye avatar con insignia UCT, nombre, estadísticas, biografía y botones de acción.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.data});

  final UserProfileData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    final colorFondoBotonAccion = esOscuro
        ? UctPalette.superficieElevadaOscura
        : const Color(0xFFEAF3FA);
    final colorBordeBotonAccion = esOscuro
        ? UctPalette.bordeOscuro
        : const Color(0xFFD4E6F4);
    final colorTextoBotonAccion = esOscuro
        ? UctPalette.celeste
        : const Color(0xFF0C3860);

    final colorFondoBotonQr = esOscuro
        ? UctPalette.amarillo.withValues(alpha: 0.18)
        : const Color(0xFFFCF4D8);
    final colorBordeBotonQr = esOscuro
        ? UctPalette.bordeOscuro
        : const Color(0xFFF5E4A8);
    final colorIconoQr = esOscuro
        ? UctPalette.amarillo
        : const Color(0xFF825F00);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Avatar + (Nombre y Estadísticas)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar circular con insignia dorada
              _ProfileAvatar(esOscuro: esOscuro),
              const SizedBox(width: 20),

              // Nombre y Métricas a la derecha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            value: '${data.uploadedCount}',
                            label: 'subidos',
                            colorScheme: colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                            value: '${data.savedCount}',
                            label: 'guardados',
                            colorScheme: colorScheme,
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                            value: data.reputation.toStringAsFixed(1),
                            label: 'reputación',
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Biografía
          Text(
            data.bio,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  text: 'Editar perfil',
                  backgroundColor: colorFondoBotonAccion,
                  borderColor: colorBordeBotonAccion,
                  textColor: colorTextoBotonAccion,
                  onTap: () => EditProfileSheet.show(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  text: 'Ver insignias',
                  backgroundColor: colorFondoBotonAccion,
                  borderColor: colorBordeBotonAccion,
                  textColor: colorTextoBotonAccion,
                  onTap: () => BadgesModalSheet.show(context, data.badges),
                ),
              ),
              const SizedBox(width: 10),
              // Botón QR
              Container(
                width: 48,
                height: 44,
                decoration: BoxDecoration(
                  color: colorFondoBotonQr,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorBordeBotonQr),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Código QR de Perfil'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 140,
                              color: colorIconoQr,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ApuntesUCT: ${data.id}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Center(
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: colorIconoQr,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.esOscuro});

  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: esOscuro
                  ? UctPalette.superficieElevadaOscura
                  : const Color(0xFFEAF4FB),
              border: Border.all(
                color: esOscuro
                    ? UctPalette.bordeOscuro
                    : const Color(0xFFD6E8F5),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.person_rounded,
                size: 54,
                color: esOscuro
                    ? UctPalette.textoSuaveOscuro
                    : const Color(0xFF90B5D0),
              ),
            ),
          ),
          // Badge amarillo UCT en la esquina inferior derecha
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UctPalette.amarillo,
                border: Border.all(
                  color: esOscuro
                      ? UctPalette.fondoOscuro
                      : Theme.of(context).colorScheme.surface,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.colorScheme,
  });

  final String value;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
