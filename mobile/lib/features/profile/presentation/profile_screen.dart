import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/uct_palette.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../auth/data/mock_auth_repository.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_courses_section.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_materials_grid.dart';

/// Pantalla de Perfil de Usuario para ApuntesUCT (Issue #57).
///
/// Reproduce fielmente la maqueta con datos del usuario, cursos inscritos,
/// cuadrícula de materiales subidos, barra de navegación inferior
/// y soporte completo para modo claro y oscuro.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final profileData = ref.watch(profileDataProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // -----------------------------------------------------------------------
      // AppBar personalizada según la maqueta
      // -----------------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: _TopIconButton(
              icon: Icons.settings_outlined,
              tooltip: 'Ajustes',
              onTap: () => _mostrarMenuAjustes(context, ref),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Isotipo circular UCT (mitad azul, mitad amarillo)
            const _UctIsotype(),
            const SizedBox(width: 8),
            Text(
              'Perfil',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Botón para alternar tema claro / oscuro
          const ThemeToggleButton(),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _TopIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notificaciones',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No tienes notificaciones pendientes'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Contenido del Perfil
      // -----------------------------------------------------------------------
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            ProfileHeaderCard(data: profileData),
            const SizedBox(height: 12),
            ProfileCoursesSection(courses: profileData.courses),
            const SizedBox(height: 20),
            ProfileMaterialsGrid(
              materials: profileData.uploadedMaterials,
              courses: profileData.courses,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),

      // -----------------------------------------------------------------------
      // Barra de navegación inferior
      // -----------------------------------------------------------------------
      bottomNavigationBar: _ProfileBottomNav(
        esOscuro: esOscuro,
        activeIndex: 3, // Perfil activo
        onTabSelected: (index) => _onNavTabSelected(context, index),
      ),
    );
  }

  void _onNavTabSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.push('/search');
        break;
      case 2:
        context.push('/library');
        break;
      case 3:
        // Ya estamos en perfil
        break;
    }
  }

  void _mostrarMenuAjustes(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ajustes y Cuenta',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tema'),
                  trailing: const ThemeToggleButton(),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Acerca de ApuntesUCT'),
                  subtitle: const Text('Versión 1.0.0 (Sprint 1)'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Componentes de apoyo visual para la pantalla
// -----------------------------------------------------------------------------

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: esOscuro
            ? UctPalette.superficieOscura
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              esOscuro ? UctPalette.bordeOscuro : colorScheme.outlineVariant,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: colorScheme.onSurface, size: 22),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
}

class _UctIsotype extends StatelessWidget {
  const _UctIsotype();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.5),
      ),
      child: ClipOval(
        child: Row(
          children: [
            Expanded(
              child: Container(color: UctPalette.azul),
            ),
            Expanded(
              child: Container(color: UctPalette.amarillo),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBottomNav extends StatelessWidget {
  const _ProfileBottomNav({
    required this.esOscuro,
    required this.activeIndex,
    required this.onTabSelected,
  });

  final bool esOscuro;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.search_rounded, label: 'Buscar'),
    _NavItem(icon: Icons.bookmark_rounded, label: 'Guardados'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorFondo =
        esOscuro ? const Color(0xFF0F1722) : const Color(0xFF0A3B65);

    return Container(
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _navItems.length; i++)
                Expanded(
                  child: _NavTabButton(
                    item: _navItems[i],
                    isActive: i == activeIndex,
                    onTap: () => onTabSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? UctPalette.amarillo : const Color(0xFF8FBAD8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: isActive ? 26 : 22),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
