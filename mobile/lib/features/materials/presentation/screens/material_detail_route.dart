import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_detail_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Contenedor de ruta que resuelve el detalle por ID.
///
/// Separa el ruteo (`GoRoute(path: '/materials/:id')`) de la UI
/// ([MaterialDetailScreen]), que sigue recibiendo un [MaterialDetail].
class MaterialDetailRoute extends ConsumerWidget {
  const MaterialDetailRoute({
    super.key,
    required this.materialId,
    this.versionPickFile,
  });

  final String materialId;

  /// Seam para tests: se propaga a la hoja de subida de versiones.
  final Future<MaterialPickedFile?> Function()? versionPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (materialId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Material')),
        body: Center(
          child: ErrorState(
            message: 'Identificador de material inválido.',
            onRetry: () => context.go('/materials'),
          ),
        ),
      );
    }

    final detailAsync = ref.watch(materialDetailByIdProvider(materialId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Detalle del Material')),
        body: const Center(
          child: LoadingState(message: 'Cargando material...'),
        ),
      ),
      error: (error, _) {
        // ID inexistente → estado vacío, no error genérico ni pantalla
        // en blanco. Otros fallos (red, repo) → ErrorState con reintento.
        if (error is MaterialNotFoundException) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del Material')),
            body: const Center(
              child: EmptyState(
                title: 'Material no encontrado',
                subtitle:
                    'El material solicitado no existe o aún no está publicado.',
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Detalle del Material')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorState(
                    message: 'No fue posible cargar el material solicitado.',
                    onRetry: () =>
                        ref.invalidate(materialDetailByIdProvider(materialId)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/materials'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver al listado'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (detail) {
        // Defensa ante un repositorio que devuelva un detalle ajeno al ID
        // pedido (era el caso del mock que siempre devolvía mat-101):
        // nunca mostrar contenido equivocado como si fuera el solicitado.
        if (detail.summary.id != materialId) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del Material')),
            body: const Center(
              child: EmptyState(
                title: 'Material no encontrado',
                subtitle:
                    'El material solicitado no existe o aún no está publicado.',
              ),
            ),
          );
        }
        return MaterialDetailScreen(
          detail: detail,
          versionPickFile: versionPickFile,
        );
      },
    );
  }
}
