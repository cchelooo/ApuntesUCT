import 'package:flutter/material.dart';

/// Apariencia semántica de un [AppButton].
enum AppButtonVariant { primary, secondary, text }

/// Botón reutilizable de la aplicación.
///
/// Las variantes expresan jerarquía, no colores concretos: cada una toma su
/// apariencia del tema activo. El estado de carga deshabilita la interacción y
/// conserva el tamaño del control para evitar dobles envíos y saltos de layout.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
    this.fullWidth = false,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
    this.fullWidth = false,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
    this.fullWidth = false,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;
  final bool fullWidth;
  final IconData? icon;
  final AppButtonVariant variant;

  static const double _defaultHeight = 54;
  static const double _compactHeight = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = compact ? _compactHeight : _defaultHeight;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
    );
    final callback = isLoading ? null : onPressed;
    final progressColor = switch (variant) {
      AppButtonVariant.primary => colorScheme.onPrimary,
      AppButtonVariant.secondary =>
        theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}) ??
            colorScheme.primary,
      AppButtonVariant.text =>
        theme.textButtonTheme.style?.foregroundColor?.resolve({}) ??
            colorScheme.primary,
    };
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
      progressColor: progressColor,
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        style: style,
        onPressed: callback,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        style: style,
        onPressed: callback,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        style: style,
        onPressed: callback,
        child: child,
      ),
    };

    final sizedButton = SizedBox(
      width: fullWidth ? double.infinity : null,
      child: button,
    );

    if (!isLoading) return sizedButton;

    return Semantics(
      button: true,
      enabled: false,
      liveRegion: true,
      label: '$label, cargando',
      child: ExcludeSemantics(child: sizedButton),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.progressColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: progressColor,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Text(label),
      ],
    );
  }
}
