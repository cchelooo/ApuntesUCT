import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/moderation_queue_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Destino de navegación `/moderation/materials/:id` (#409 -> #410).
///
/// Conserva el [materialId] recibido por ruta, valida permisos de moderación
/// y ofrece navegación coherente de regreso a `/moderation`.
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
              const Icon(Icons.fact_check_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Material en revisión',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: $materialId',
                key: Key('moderation_review_material_id_$materialId'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                key: const Key('moderation_review_back_button'),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/moderation');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver a la cola'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
