import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ruta `/materials/upload` (issue #279).
///
/// Placeholder intencional: la maqueta real del formulario llega en #280.
/// Existe para reservar la ruta, evitar pantalla en blanco y dar un punto
/// de entrada desde Home / navegación inferior sin tocar el catálogo.
class MaterialUploadScreen extends StatelessWidget {
  const MaterialUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Material'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparte tus apuntes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'El formulario de subida (archivo o enlace + metadatos) '
                'se maqueta en la issue #280. Esta pantalla reserva la ruta '
                '`/materials/upload` para que la navegación no falle.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => context.push('/materials'),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explorar materiales'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Volver al inicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
