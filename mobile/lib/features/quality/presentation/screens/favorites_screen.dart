import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/models/favorite_item.dart';
import '../providers/favorites_provider.dart';
import '../widgets/favorite_card.dart';

/// Pantalla de Favoritos personales de ApuntesUCT (Issue #396 - S3-M09).
///
/// Implementa los estados de la interfaz visual en fase de preparación:
/// - Carga (`LoadingState`)
/// - Lista con datos (`FavoriteCard` con navegación por `materialId`)
/// - Lista vacía (`EmptyState`)
/// - Error con reintento (`ErrorState` con callback `retry`)
///
/// Cumple con el Criterio 4 incluyendo aviso explícito de preparación visual
/// previo a la integración con API real en la Semana 3.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mis Favoritos'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // Selector de escenarios para pruebas y QA (Criterio 1 y 4)
          PopupMenuButton<FavoritesDemoScenario>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Cambiar escenario de prueba (S3-M09)',
            onSelected: (scenario) {
              ref.read(favoritesProvider.notifier).setScenario(scenario);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: FavoritesDemoScenario.withData,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Lista con datos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: FavoritesDemoScenario.empty,
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Lista vacía'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: FavoritesDemoScenario.error,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Error con reintento'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: FavoritesDemoScenario.loading,
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Estado de carga'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo de preparación visual (Criterio 4)
          _PreparationNoticeBanner(noticeText: FavoritesFixtures.preparationNotice),
          Expanded(
            child: _buildBody(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, FavoritesState state) {
    switch (state.status) {
      case FavoritesStatus.initial:
      case FavoritesStatus.loading:
        return const LoadingState(
          message: 'Cargando favoritos guardados...',
        );

      case FavoritesStatus.error:
        return ErrorState(
          title: 'No pudimos cargar tus favoritos',
          message: state.errorMessage ??
              'Ocurrió un error inesperado al consultar tus materiales guardados.',
          icon: Icons.bookmark_remove_rounded,
          onRetry: () => ref.read(favoritesProvider.notifier).retry(),
        );

      case FavoritesStatus.empty:
        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  title: 'Sin favoritos guardados',
                  subtitle:
                      'Los materiales que marques como favoritos aparecerán aquí para que accedas a ellos rápidamente.',
                  icon: Icons.bookmark_border_rounded,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    try {
                      GoRouter.of(context).push('/materials');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explorar materiales'),
                ),
              ],
            ),
          ),
        );

      case FavoritesStatus.data:
        if (state.items.isEmpty) {
          return const EmptyState(
            title: 'Sin favoritos guardados',
            subtitle:
                'Los materiales que marques como favoritos aparecerán aquí para que accedas a ellos rápidamente.',
            icon: Icons.bookmark_border_rounded,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return FavoriteCard(
                key: ValueKey(item.id),
                item: item,
                onTap: () {
                  try {
                    GoRouter.of(context).push('/materials/${item.materialId}');
                  } catch (_) {}
                },
              );
            },
          ),
        );
    }
  }
}

/// Banner visual explícito que identifica la vista en preparación (Criterio 4).
class _PreparationNoticeBanner extends StatelessWidget {
  final String noticeText;

  const _PreparationNoticeBanner({required this.noticeText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              noticeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
