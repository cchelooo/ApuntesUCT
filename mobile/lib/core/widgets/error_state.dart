import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Ocurrió un problema',
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
  });

  /// Constructor inteligente que infiere el ícono y el título basándose en el mensaje
  factory ErrorState.fromMessage({
    Key? key,
    required String message,
    VoidCallback? onRetry,
  }) {
    String title = 'Ocurrió un problema';
    IconData icon = Icons.error_outline_rounded;

    final lowerMessage = message.toLowerCase();

    // Errores de red
    if (lowerMessage.contains('conexión') || 
        lowerMessage.contains('tiempo de espera') ||
        lowerMessage.contains('red')) {
      title = 'Error de conexión';
      icon = Icons.wifi_off_rounded;
    } 
    // Errores de validación / cliente
    else if (lowerMessage.contains('validación') || 
             lowerMessage.contains('archivo') ||
             lowerMessage.contains('incompleto')) {
      title = 'Revisa los datos';
      icon = Icons.rule_rounded;
    } 
    // Errores de no encontrado
    else if (lowerMessage.contains('no encontrado') || 
             lowerMessage.contains('no existe')) {
      title = 'No encontrado';
      icon = Icons.find_in_page_rounded;
    }
    // Errores de servidor
    else if (lowerMessage.contains('servidor')) {
      title = 'Error del servidor';
      icon = Icons.cloud_off_rounded;
    }

    return ErrorState(
      key: key,
      title: title,
      message: message,
      icon: icon,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}