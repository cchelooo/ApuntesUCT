import 'package:flutter/material.dart';
import 'package:apuntesuct_mobile/core/errors/api_exception.dart'; // Asegúrate de tener este import

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

  /// Constructor inteligente basado en ApiException, statusCode o mensajes del Gateway
  factory ErrorState.fromMessage({
    Key? key,
    Object? error,
    required String message,
    VoidCallback? onRetry,
  }) {
    String title = 'Ocurrió un problema';
    IconData icon = Icons.error_outline_rounded;

    int? statusCode;
    if (error is ApiException) {
      statusCode = error.statusCode;
    }

    final lowerMessage = message.toLowerCase();

    // 1. Clasificación por Código HTTP o tipo de error de red
    if (statusCode == 401 || statusCode == 403) {
      title = 'Acceso no autorizado';
      icon = Icons.lock_outline_rounded;
    } else if (statusCode == 404) {
      title = 'No encontrado';
      icon = Icons.find_in_page_rounded;
    } else if (statusCode != null && statusCode >= 500) {
      title = 'Error del servidor';
      icon = Icons.cloud_off_rounded;
    } else if (lowerMessage.contains('timeout') ||
        lowerMessage.contains('tiempo de espera') ||
        lowerMessage.contains('conexión') ||
        lowerMessage.contains('red') ||
        lowerMessage.contains('no disponible')) {
      title = 'Error de conexión';
      icon = Icons.wifi_off_rounded;
    } else if (lowerMessage.contains('validación') ||
        lowerMessage.contains('archivo') ||
        statusCode == 400) {
      title = 'Revisa los datos';
      icon = Icons.rule_rounded;
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
            Icon(icon, size: 56, color: colorScheme.error),
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
