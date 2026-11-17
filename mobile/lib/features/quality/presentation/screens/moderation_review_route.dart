import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/quality/domain/repositories/quality_moderation_repository.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_queue_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_review_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/screens/moderation_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Destino de navegación `/moderation/materials/:id` (#409 -> #410).
class ModerationReviewRoute extends ConsumerWidget {
  final String materialId;
  final String? userRole;

  const ModerationReviewRoute({
    super.key,
    required this.materialId,
    this.userRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveRole = userRole ?? ref.watch(moderationUserRoleProvider);
    final isAuthorized = isModeratorRole(effectiveRole);

    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Revisión de Material'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Acceso restringido',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'No cuentas con permisos de moderación para revisar este material.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (materialId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Revisión de Material'),
          centerTitle: true,
        ),
        body: Center(
          child: ErrorState.fromMessage(
            message: 'Identificador de material inválido.',
            onRetry: () => context.go('/moderation'),
          ),
        ),
      );
    }

    final detailAsync = ref.watch(moderationMaterialDetailProvider(materialId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Revisión de Material'),
          centerTitle: true,
        ),
        body: const Center(
          child: LoadingState(message: 'Cargando detalle para revisión...'),
        ),
      ),
      error: (error, _) {
        if (error is ModerationMaterialNotFoundException) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Revisión de Material'),
              centerTitle: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      title: 'Material no disponible para revisión',
                      subtitle: 'El material solicitado no existe o ya no se encuentra pendiente.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('moderation_review_back_button'),
                      onPressed: () => context.go('/moderation'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver a la cola'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final message =
            (error is ApiException &&
                (error.statusCode == 401 || error.statusCode == 403))
            ? 'No tienes autorización para consultar este material.'
            : apiErrorMessage(
                error,
                fallback: 'No se pudo cargar el detalle del material.',
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Revisión de Material'),
            centerTitle: true,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorState.fromMessage(
                    error: error,
                    message: message,
                    onRetry: () => ref.invalidate(
                      moderationMaterialDetailProvider(materialId),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('moderation_review_back_button'),
                    onPressed: () => context.go('/moderation'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a la cola'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (detail) {
        if (detail.materialId != materialId) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Revisión de Material'),
              centerTitle: true,
            ),
            body: const Center(
              child: EmptyState(
                title: 'Material no disponible para revisión',
                subtitle: 'El identificador recibido no coincide con el material solicitado.',
              ),
            ),
          );
        }
        return ModerationReviewScreen(detail: detail);
      },
    );
  }
}
