import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/moderation_queue_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Vista privada para que personas moderadoras revisen materiales pendientes (#409).
class ModerationQueueScreen extends ConsumerStatefulWidget {
  final String? userRole;
  final void Function(MaterialSummary material)? onSelectMaterial;

  const ModerationQueueScreen({
    super.key,
    this.userRole,
    this.onSelectMaterial,
  });

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      ref.read(moderationQueueProvider.notifier).loadNextPage();
    }
  }

  void _handleSelect(BuildContext context, MaterialSummary item) {
    if (widget.onSelectMaterial != null) {
      widget.onSelectMaterial!(item);
      return;
    }
    try {
      GoRouter.of(context).push('/moderation/materials/${item.id}');
    } catch (_) {
      // Fallback cuando GoRouter no está montado en pruebas aisladas.
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRole =
        widget.userRole ?? ref.watch(moderationUserRoleProvider);
    final isAuthorized = isModeratorRole(effectiveRole);

    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cola de Moderación'),
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
                  'No cuentas con permisos de moderación para visualizar esta sección.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (Navigator.of(context).canPop()) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(moderationQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de Moderación'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('moderation_refresh_button'),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar cola',
            onPressed: state.isLoading
                ? null
                : () => ref.read(moderationQueueProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!state.isLoading &&
              state.errorMessage == null &&
              state.items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                'Pendientes por revisar: ${state.total}',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(moderationQueueProvider.notifier).refresh(),
              child: _buildBody(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ModerationQueueState state) {
    if (state.isLoading) {
      return const LoadingState(message: 'Cargando cola de revisión...');
    }

    if (state.errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ErrorState.fromMessage(
            error: state.error,
            message: state.errorMessage!,
            onRetry: () => ref.read(moderationQueueProvider.notifier).refresh(),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              title: 'Sin materiales pendientes',
              subtitle: 'No hay materiales esperando revisión en este momento.',
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        final item = state.items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                'ID: ${item.id}',
                key: Key('pending_material_id_${item.id}'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            MaterialSummaryCard(
              material: item,
              onTap: () => _handleSelect(context, item),
            ),
          ],
        );
      },
    );
  }
}
