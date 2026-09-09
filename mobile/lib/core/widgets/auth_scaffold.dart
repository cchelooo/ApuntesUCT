import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/uct_palette.dart';

/// Estructura visual compartida por las pantallas de autenticación.
///
/// Login y Registro comparten fondo, encabezado de marca, ancho máximo,
/// espaciado y manejo del teclado. Tenerlo en un solo widget es lo que asegura
/// que ambas se vean como parte de la misma aplicación y que un ajuste de diseño
/// no haya que replicarlo a mano.
///
/// No decide colores: los toma del tema, así que el mismo código rinde la
/// dirección "Celeste claro" en modo claro y "Navy nocturno" en modo oscuro.
/// Lo único que consulta el brillo es el fondo decorativo, porque cada modo
/// tiene una figura distinta.
///
/// Detalles de comportamiento que resuelve:
/// - el contenido es desplazable, así el teclado no provoca overflow;
/// - el ancho se limita a 440 px, para que en tablet el formulario no se estire
///   de borde a borde;
/// - el contenido queda centrado verticalmente cuando sobra espacio, y se
///   comporta como lista normal cuando falta.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.isRegistration = false,
    this.bottomAction,
    this.footer,
    this.actions,
    super.key,
  });

  /// Título principal de la pantalla.
  final String title;

  /// Texto de apoyo bajo el título.
  final String subtitle;

  /// Contenido del formulario.
  final List<Widget> children;

  /// Ajusta la densidad vertical a la variante de Registro de la maqueta.
  final bool isRegistration;

  /// Acción principal que se ancla al fondo disponible de la pantalla.
  final Widget? bottomAction;

  /// Zona inferior fija, normalmente el enlace a la otra pantalla de auth.
  final Widget? footer;

  /// Acciones de la barra superior, como el interruptor de tema.
  final List<Widget>? actions;

  static const double _paddingHorizontal = 26;
  static const double _paddingTop = 42;
  static const double _paddingBottom = 26;
  static const double _paddingHorizontalLandscape = 28;
  static const double _paddingVerticalLandscape = 18;
  static const double _anchoMaximo = 440;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // El fondo decorativo sube hasta detrás de la barra: sin esto quedaría
      // una franja plana arriba y la figura empezaría cortada.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Sólo se muestra la flecha si hay algo a lo que volver; en Login, que
        // es la raíz del flujo, el espacio queda libre a propósito.
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: actions,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AuthBackdropPainter(brightness: theme.brightness),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esHorizontal =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxWidth >= 600;

                return esHorizontal
                    ? _buildLandscapeLayout(constraints)
                    : _buildPortraitLayout(constraints);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    final double height = math.max(
      0.0,
      constraints.maxHeight - _paddingTop - _paddingBottom,
    );
    final double width = math.min(
      math.max(0.0, constraints.maxWidth - (_paddingHorizontal * 2)),
      _anchoMaximo,
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        _paddingHorizontal,
        _paddingTop,
        _paddingHorizontal,
        _paddingBottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: title,
                    subtitle: subtitle,
                    isRegistration: isRegistration,
                  ),
                  SizedBox(height: isRegistration ? 18 : 26),
                  ...children,
                ],
              ),
            ),
            if (bottomAction != null) ...[
              SizedBox(
                height: math.max(
                  24.0,
                  height - (isRegistration ? 400.0 : 450.0),
                ),
              ),
              SizedBox(width: width, child: bottomAction!),
            ],
            if (footer != null) ...[
              SizedBox(height: isRegistration ? 14 : 20),
              SizedBox(width: width, child: footer!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    final double width = math.max(
      0.0,
      constraints.maxWidth - (_paddingHorizontalLandscape * 2),
    );
    final double height = math.max(
      0.0,
      constraints.maxHeight - (_paddingVerticalLandscape * 2),
    );
    final double gap = math.min(36.0, width * 0.06);
    final double formWidth = math.min(
      _anchoMaximo,
      math.max(280.0, width * 0.56),
    );
    final double headerWidth = math.max(0.0, width - formWidth - gap);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: _paddingHorizontalLandscape,
        vertical: _paddingVerticalLandscape,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Center(
          child: SizedBox(
            width: width,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: headerWidth,
                  child: _Header(
                    title: title,
                    subtitle: subtitle,
                    isRegistration: isRegistration,
                    compact: true,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: formWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...children,
                      if (bottomAction != null) ...[
                        SizedBox(height: isRegistration ? 14 : 18),
                        bottomAction!,
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 14),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado con la marca, el título y el subtítulo.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.isRegistration,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool isRegistration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final esOscuro = theme.brightness == Brightness.dark;
    final titleText = esOscuro && title == 'Iniciar sesión' && !compact
        ? 'Iniciar\nsesión'
        : title;
    final titleSize = compact
        ? (isRegistration ? 27.0 : 30.0)
        : esOscuro
        ? (isRegistration ? 30.0 : 34.0)
        : (isRegistration ? 29.0 : 32.0);
    final titleGap = compact
        ? (isRegistration ? 22.0 : 24.0)
        : esOscuro
        ? (isRegistration ? 38.0 : 58.0)
        : (isRegistration ? 45.0 : 76.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                // En oscuro la marca va en amarillo, que es el color primario de
                // la identidad; en claro, en azul, para no gritar sobre blanco.
                color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                borderRadius: BorderRadius.circular(esOscuro ? 8 : 11),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 19,
                color: esOscuro ? UctPalette.navy : Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ApuntesUCT',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: esOscuro ? colorScheme.onSurface : UctPalette.azulOscuro,
              ),
            ),
          ],
        ),
        SizedBox(height: titleGap),
        Text(
          titleText,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: titleSize,
            color: esOscuro ? colorScheme.onSurface : UctPalette.azulOscuro,
          ),
        ),
        // Regla amarilla: el guiño de marca que aparece en los dos modos.
        Container(
          width: 46,
          height: 4,
          margin: EdgeInsets.only(top: esOscuro ? 13 : 0),
          color: UctPalette.amarillo,
        ),
        if (!esOscuro && isRegistration) const SizedBox(height: 8),
        if (!esOscuro && !isRegistration) const SizedBox(height: 10),
        if (esOscuro) const SizedBox(height: 13),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: compact ? 13 : null,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Fondo decorativo de las pantallas de acceso.
///
/// Cada modo tiene su figura, y son las de las maquetas aprobadas:
/// - **oscuro**: dos círculos arriba a la derecha, uno lleno y otro apenas
///   dibujado en amarillo, que insinúan profundidad sobre el navy;
/// - **claro**: una banda celeste con el borde inferior curvo, un círculo de
///   apoyo y un punto amarillo suelto.
///
/// Las coordenadas están tomadas de la maqueta, que mide 390 px de ancho, y se
/// escalan al ancho real: así la figura conserva su proporción en cualquier
/// teléfono en vez de quedar descentrada.
class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter({required this.brightness});

  final Brightness brightness;

  /// Ancho de referencia de la maqueta.
  static const double _anchoMaqueta = 390;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width > size.height) {
      if (brightness == Brightness.dark) {
        _pintarOscuroHorizontal(canvas, size);
      } else {
        _pintarClaroHorizontal(canvas, size);
      }
      return;
    }

    final k = size.width / _anchoMaqueta;
    if (brightness == Brightness.dark) {
      _pintarOscuro(canvas, k);
    } else {
      _pintarClaro(canvas, k);
    }
  }

  void _pintarOscuro(Canvas canvas, double k) {
    canvas.drawCircle(
      Offset(330 * k, 40 * k),
      130 * k,
      Paint()..color = UctPalette.navyElevado,
    );
    canvas.drawCircle(
      Offset(319 * k, 61 * k),
      37 * k,
      Paint()
        ..color = UctPalette.amarillo.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * k,
    );
  }

  void _pintarOscuroHorizontal(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width - 60, 40),
      130,
      Paint()..color = UctPalette.navyElevado,
    );
    canvas.drawCircle(
      Offset(size.width - 71, 61),
      37,
      Paint()
        ..color = UctPalette.amarillo.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _pintarClaro(Canvas canvas, double k) {
    final banda = Path()
      ..moveTo(0, 0)
      ..lineTo(390 * k, 0)
      ..lineTo(390 * k, 186 * k)
      ..cubicTo(326 * k, 226 * k, 240 * k, 232 * k, 158 * k, 208 * k)
      ..cubicTo(86 * k, 190 * k, 44 * k, 196 * k, 0, 214 * k)
      ..close();

    canvas.drawPath(banda, Paint()..color = UctPalette.celesteClaro);
    canvas.drawCircle(
      Offset(336 * k, 60 * k),
      52 * k,
      Paint()..color = UctPalette.celesteTinte,
    );
    canvas.drawCircle(
      Offset(66 * k, 196 * k),
      9 * k,
      Paint()..color = UctPalette.amarillo,
    );
  }

  void _pintarClaroHorizontal(Canvas canvas, Size size) {
    final k = size.width / _anchoMaqueta;
    final banda = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 186)
      ..cubicTo(326 * k, 226, 240 * k, 232, 158 * k, 208)
      ..cubicTo(86 * k, 190, 44 * k, 196, 0, 214)
      ..close();

    canvas.drawPath(banda, Paint()..color = UctPalette.celesteClaro);
    canvas.drawCircle(
      Offset(size.width - 54, 60),
      52,
      Paint()..color = UctPalette.celesteTinte,
    );
    canvas.drawCircle(
      Offset(66 * k, 196),
      9,
      Paint()..color = UctPalette.amarillo,
    );
  }

  @override
  bool shouldRepaint(_AuthBackdropPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
