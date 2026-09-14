import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/home_state.dart';
import 'widgets/course_card.dart';
import 'widgets/material_card.dart';

// ---------------------------------------------------------------------------
// Constantes de color de la pantalla Home
// ---------------------------------------------------------------------------

const _kNavyDark = Color(0xFF16324F);
const _kBlueLink = Color(0xFF1E6FB8);
const _kBgPage = Color(0xFFEEF2F6);
const _kNavBg = Color(0xFF16324F);
const _kNavActive = Color(0xFFEAA83A);
const _kNavInactive = Color(0xFFB0BEC5);

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

/// Pantalla principal de ApuntesUCT (issue #56).
///
/// Muestra tres secciones horizontales scrolleables:
/// - "Tus cursos" — [CourseCard] con colores alternados
/// - "Material recomendado" — [MaterialCard] sin rating/downloads
/// - "Mejores calificados del día" — [MaterialCard] con rating y downloads
///
/// El tab activo del [BottomNavigationBar] vive en [navTabProvider] (Riverpod),
/// no en estado local del widget.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final activeTab = ref.watch(navTabProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kBgPage,
        // ----------------------------------------------------------------
        // AppBar
        // ----------------------------------------------------------------
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleSpacing: 16,
          title: Row(
            children: [
              // Logo circular con iniciales de marca
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1F6FB2), Color(0xFFEAA83A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ApuntesUCT',
                style: TextStyle(
                  color: _kNavyDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        // ----------------------------------------------------------------
        // Body
        // ----------------------------------------------------------------
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Encabezado de página ----
              _PageHeader(),
              const SizedBox(height: 8),
              // ---- Tus cursos ----
              _SectionHeader(
                title: 'Tus cursos',
                actionLabel: 'Ver todos',
                onAction: () {},
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
                onAction: () {},
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
                onAction: () {},
              ),
              const SizedBox(height: 12),
              _HorizontalList(
                height: 192,
                children: [
                  for (final item in homeState.topRated)
                    MaterialCard(data: item),
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
          onTabSelected: (index) =>
              ref.read(navTabProvider.notifier).selectTab(index),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado de página
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kBgPage,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inicio',
            style: TextStyle(
              color: _kNavyDark,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Material académico útil, filtrado por tus cursos y actividad reciente.',
            style: TextStyle(
              color: const Color(0xFF5B7089),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
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
              style: const TextStyle(
                color: _kBlueLink,
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
  const _HorizontalList({
    required this.height,
    required this.children,
  });

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
    return Container(
      decoration: const BoxDecoration(
        color: _kNavBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
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
    final color = isActive ? _kNavActive : _kNavInactive;

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
