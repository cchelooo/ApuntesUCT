import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:apuntesuct_mobile/core/widgets/widgets.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authStateProvider;

import 'providers/home_provider.dart';
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

  void _onDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    AppNavigationDestination destination,
  ) {
    ref.read(navTabProvider.notifier).selectTab(destination.index);
    switch (destination) {
      case AppNavigationDestination.home:
        break;
      case AppNavigationDestination.search:
        context.push('/search').then((_) {
          ref.read(navTabProvider.notifier).selectTab(0);
        });
        break;
      case AppNavigationDestination.library:
        context.push('/library').then((_) {
          ref.read(navTabProvider.notifier).selectTab(0);
        });
        break;
      case AppNavigationDestination.profile:
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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: Text(
                  'ApuntesUCT',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
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
            AppSectionHeader(
              title: 'Tus cursos',
              actionLabel: 'Ver todos',
              onAction: () => context.push('/catalog'),
            ),
            const SizedBox(height: 12),
            AppHorizontalList(
              height: 148,
              itemCount: homeState.courses.length,
              itemBuilder: (context, i) =>
                  CourseCard(entry: homeState.courses[i], index: i),
              spacing: 0,
            ),
            const SizedBox(height: 24),
            // ---- Material recomendado ----
            AppSectionHeader(
              title: 'Material recomendado',
              actionLabel: 'Más',
              onAction: () => context.push('/catalog'),
            ),
            const SizedBox(height: 12),
            AppHorizontalList(
              height: 162,
              itemCount: homeState.recommended.length,
              itemBuilder: (context, i) =>
                  MaterialCard(data: homeState.recommended[i]),
              spacing: 0,
            ),
            const SizedBox(height: 24),
            // ---- Mejores calificados del día ----
            AppSectionHeader(
              title: 'Mejores calificados del día',
              actionLabel: 'Ranking',
              onAction: () => context.push('/search'),
            ),
            const SizedBox(height: 12),
            AppHorizontalList(
              height: 192,
              itemCount: homeState.topRated.length,
              itemBuilder: (context, i) =>
                  MaterialCard(data: homeState.topRated[i]),
              spacing: 0,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      // ----------------------------------------------------------------
      // Bottom Navigation Bar
      // ----------------------------------------------------------------
      bottomNavigationBar: AppNavigationBar(
        selectedDestination: AppNavigationDestination.values[activeTab],
        onDestinationSelected: (destination) =>
            _onDestinationSelected(context, ref, destination),
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
