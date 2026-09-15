import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/theme_toggle_button.dart';
import '../features/auth/data/mock_auth_repository.dart' show authStateProvider;
import '../state/home_state.dart';
import 'widgets/course_card.dart';
import 'widgets/material_card.dart';

/// Pantalla principal de ApuntesUCT (issue #56).
///
/// Muestra tres secciones horizontales scrolleables:
/// - "Tus cursos" — [CourseCard] con colores alternados
/// - "Material recomendado" — [MaterialCard] sin rating/downloads
/// - "Mejores calificados del día" — [MaterialCard] con rating y downloads
///
/// Consume [Theme.of(context).colorScheme] para responder al tema claro y oscuro
/// de acuerdo a `docs/mobile/tema-visual.md`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _onTabSelected(BuildContext context, WidgetRef ref, int index) {
    ref.read(navTabProvider.notifier).selectTab(index);
    switch (index) {
      case 0:
        break;
      case 1:
        context.push('/search').then((_) {
          ref.read(navTabProvider.notifier).selectTab(0);
        });
        break;
      case 2:
        context.push('/library').then((_) {
          ref.read(navTabProvider.notifier).selectTab(0);
        });
        break;
      case 3:
        context.push('/profile').then((_) {
          ref.read(navTabProvider.notifier).selectTab(0);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final activeTab = ref.watch(navTabProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // ----------------------------------------------------------------
      // AppBar
      // ----------------------------------------------------------------
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            // Isotipo con inicial de marca
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary,
              ),
              child: Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ApuntesUCT',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      // ----------------------------------------------------------------
      // Body
      // ----------------------------------------------------------------
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Encabezado de página ----
            const _PageHeader(),
            const SizedBox(height: 8),
            // ---- Tus cursos ----
            _SectionHeader(
              title: 'Tus cursos',
              actionLabel: 'Ver todos',
              onAction: () => context.push('/catalog'),
            ),
            const SizedBox(height: 12),
            _HorizontalList(
              height: 148,
              children: [
                for (var i = 0; i < homeState.courses.length; i++)
                  CourseCard(entry: homeState.courses[i], index: i),
              ],
            ),
            const SizedBox(height: 24),
            // ---- Material recomendado ----
            _SectionHeader(
              title: 'Material recomendado',
              actionLabel: 'Más',
              onAction: () => context.push('/catalog'),
            ),
            const SizedBox(height: 12),
            _HorizontalList(
              height: 162,
              children: [
                for (final item in homeState.recommended)
                  MaterialCard(data: item),
              ],
            ),
            const SizedBox(height: 24),
            // ---- Mejores calificados del día ----
            _SectionHeader(
              title: 'Mejores calificados del día',
              actionLabel: 'Ranking',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 12),
            _HorizontalList(
              height: 192,
              children: [
                for (final item in homeState.topRated) MaterialCard(data: item),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      // ----------------------------------------------------------------
      // Bottom Navigation Bar
      // ----------------------------------------------------------------
      bottomNavigationBar: _HomeBottomNav(
        activeIndex: activeTab,
        onTabSelected: (index) => _onTabSelected(context, ref, index),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado de página
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inicio',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Material académico útil, filtrado por tus cursos y actividad reciente.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera de sección (título + link de acción)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorEnlace = esOscuro ? colorScheme.secondary : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: TextStyle(
                color: colorEnlace,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lista horizontal con scroll independiente
// ---------------------------------------------------------------------------

class _HorizontalList extends StatelessWidget {
  const _HorizontalList({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Navigation Bar
// ---------------------------------------------------------------------------

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.activeIndex,
    required this.onTabSelected,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.search_rounded, label: 'Buscar'),
    _NavItem(icon: Icons.bookmark_rounded, label: 'Guardados'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavTabButton(
                    item: _items[i],
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: color, size: isActive ? 26 : 22),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
