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
/// dirección "Celeste claro" en modo claro y "Carbón UCT" en modo oscuro.
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
    final screenSize = MediaQuery.sizeOf(context);
    final progresoOscuro = theme.brightness == Brightness.dark ? 1.0 : 0.0;
    final esHorizontal =
        screenSize.width > screenSize.height && screenSize.width >= 520;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      // El fondo decorativo sube hasta detrás de la barra: sin esto quedaría
      // una franja plana arriba y la figura empezaría cortada.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Sólo se muestra la flecha si hay algo a lo que volver; en Login, que
        // es la raíz del flujo, el espacio queda libre a propósito.
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        toolbarHeight: esHorizontal ? 0 : null,
        actions: esHorizontal ? null : actions,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: progresoOscuro, end: progresoOscuro),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
              builder: (context, progress, child) => CustomPaint(
                painter: _AuthBackdropPainter(themeProgress: progress),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esHorizontal =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxWidth >= 520;

                return esHorizontal
                    ? _buildLandscapeLayout(constraints)
                    : _buildPortraitLayout(constraints);
              },
            ),
          ),
          if (esHorizontal && actions != null)
            Positioned(
              top: 4,
              right: 8,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    final esAlturaCorta = constraints.maxHeight < 700;
    final esAlturaMuyCorta = constraints.maxHeight < 600;
    final paddingTop = esAlturaMuyCorta
        ? 4.0
        : (esAlturaCorta ? 8.0 : _paddingTop);
    final paddingBottom = esAlturaMuyCorta
        ? 4.0
        : (esAlturaCorta ? 8.0 : _paddingBottom);
    final double height = math.max(
      0.0,
      constraints.maxHeight - paddingTop - paddingBottom,
    );
    final double width = math.min(
      math.max(0.0, constraints.maxWidth - (_paddingHorizontal * 2)),
      _anchoMaximo,
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        _paddingHorizontal,
        paddingTop,
        _paddingHorizontal,
        paddingBottom,
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
                    compact: esAlturaCorta,
                    dense: esAlturaMuyCorta,
                  ),
                  SizedBox(
                    height: esAlturaMuyCorta
                        ? (isRegistration ? 4 : 8)
                        : (esAlturaCorta
                              ? (isRegistration ? 8 : 12)
                              : (isRegistration ? 18 : 26)),
                  ),
                  ...children,
                ],
              ),
            ),
            if (bottomAction != null) ...[
              SizedBox(
                height: esAlturaMuyCorta
                    ? 0
                    : (esAlturaCorta
                          ? 4
                          : math.max(
                              24.0,
                              height - (isRegistration ? 635.0 : 585.0),
                            )),
              ),
              SizedBox(width: width, child: bottomAction!),
            ],
            if (footer != null) ...[
              SizedBox(
                height: esAlturaMuyCorta
                    ? 4
                    : (esAlturaCorta ? 8 : (isRegistration ? 14 : 20)),
              ),
              SizedBox(width: width, child: footer!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    final verticalPadding = constraints.maxHeight < 400
        ? 0.0
        : _paddingVerticalLandscape;
    final double width = math.max(
      0.0,
      constraints.maxWidth - (_paddingHorizontalLandscape * 2),
    );
    final double height = math.max(
      0.0,
      constraints.maxHeight - (verticalPadding * 2),
    );
    final double gap = math.min(36.0, width * 0.06);
    final double formRatio = width < 600 ? 0.52 : 0.56;
    final double formWidth = math.min(
      _anchoMaximo,
      math.max(260.0, width * formRatio),
    );
    final double headerWidth = math.max(0.0, width - formWidth - gap);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: _paddingHorizontalLandscape,
        vertical: verticalPadding,
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
                        SizedBox(
                          height: constraints.maxHeight < 400
                              ? (isRegistration ? 0 : 12)
                              : (isRegistration ? 14 : 18),
                        ),
                        bottomAction!,
                      ],
                      if (footer != null) ...[
                        SizedBox(height: constraints.maxHeight < 400 ? 0 : 14),
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
    this.dense = false,
  });

  final String title;
  final String subtitle;
  final bool isRegistration;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final esOscuro = theme.brightness == Brightness.dark;
    final titleText = title;
    final titleSize = dense
        ? (isRegistration ? 24.0 : 28.0)
        : compact
        ? (isRegistration ? 27.0 : 30.0)
        : (isRegistration ? 29.0 : 32.0);
    final titleGap = dense
        ? (isRegistration ? 6.0 : 10.0)
        : compact
        ? (isRegistration ? 12.0 : 20.0)
        : (isRegistration ? 45.0 : 76.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: dense ? 30 : 34,
              height: dense ? 30 : 34,
              decoration: BoxDecoration(
                // En oscuro la marca va en amarillo, que es el color primario de
                // la identidad; en claro, en azul, para no gritar sobre blanco.
                color: esOscuro ? UctPalette.amarillo : UctPalette.azul,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: dense ? 17 : 19,
                color: colorScheme.onPrimary,
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
          margin: EdgeInsets.only(top: dense ? 5 : (compact ? 7 : 10)),
          color: UctPalette.amarillo,
        ),
        SizedBox(height: dense ? 5 : (compact ? 7 : 10)),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: dense ? 11.5 : (compact ? 12.5 : null),
            height: dense ? 1.2 : (compact ? 1.35 : null),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Fondo decorativo de las pantallas de acceso.
///
/// Ambos modos comparten exactamente la misma banda curva. El pequeño acento se
/// desplaza por ella desde el sol amarillo de la izquierda hasta la luna blanca
/// de la derecha. El formulario y el resto de la composición permanecen fijos.
///
/// Las coordenadas están tomadas de la maqueta, que mide 390 px de ancho, y se
/// escalan al ancho real: así la figura conserva su proporción en cualquier
/// teléfono en vez de quedar descentrada.
class _AuthBackdropPainter extends CustomPainter {
  const _AuthBackdropPainter({required this.themeProgress});

  /// `0` representa el modo claro y `1` el oscuro.
  final double themeProgress;

  /// Ancho de referencia de la maqueta.
  static const double _anchoMaqueta = 390;

  /// Separa visualmente la curva del título sin alterar el layout del formulario.
  static const double _elevacionCurva = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width > size.height) {
      _pintarHorizontal(canvas, size);
      return;
    }

    final k = size.width / _anchoMaqueta;
    _pintarVertical(canvas, k);
  }

  void _pintarVertical(Canvas canvas, double k) {
    canvas.save();
    canvas.translate(0, -_elevacionCurva * k);

    final banda = Path()
      ..moveTo(0, 0)
      ..lineTo(390 * k, 0)
      ..lineTo(390 * k, 186 * k)
      ..cubicTo(326 * k, 226 * k, 240 * k, 232 * k, 158 * k, 208 * k)
      ..cubicTo(86 * k, 190 * k, 44 * k, 196 * k, 0, 214 * k)
      ..close();

    canvas.drawPath(
      banda,
      Paint()
        ..color = Color.lerp(
          UctPalette.celesteClaro,
          UctPalette.superficieOscura,
          themeProgress,
        )!,
    );
    _pintarAcento(
      canvas,
      claro: Offset(66 * k, 196 * k),
      oscuro: Offset(324 * k, 214 * k),
      escala: k,
    );

    canvas.restore();
  }

  void _pintarHorizontal(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, -_elevacionCurva);

    final k = size.width / _anchoMaqueta;
    final banda = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 186)
      ..cubicTo(326 * k, 226, 240 * k, 232, 158 * k, 208)
      ..cubicTo(86 * k, 190, 44 * k, 196, 0, 214)
      ..close();

    canvas.drawPath(
      banda,
      Paint()
        ..color = Color.lerp(
          UctPalette.celesteClaro,
          UctPalette.superficieOscura,
          themeProgress,
        )!,
    );
    _pintarAcento(
      canvas,
      claro: Offset(66 * k, 196),
      oscuro: Offset(size.width - 66, 210),
      escala: 1,
    );

    canvas.restore();
  }

  void _pintarAcento(
    Canvas canvas, {
    required Offset claro,
    required Offset oscuro,
    required double escala,
  }) {
    final puntoMedio = Offset.lerp(claro, oscuro, 0.5)!;
    final control = puntoMedio + Offset(0, 35 * escala);
    final centro = _puntoCuadratico(claro, control, oscuro, themeProgress);
    final radio = 10 * escala;
    final desplazamientoCorte = Offset.lerp(
      Offset(20 * escala, -20 * escala),
      Offset(5 * escala, -3 * escala),
      themeProgress,
    )!;

    final disco = Path()
      ..addOval(Rect.fromCircle(center: centro, radius: radio));
    final corte = Path()
      ..addOval(
        Rect.fromCircle(
          center: centro + desplazamientoCorte,
          radius: 8.2 * escala,
        ),
      );
    final solLuna = Path.combine(PathOperation.difference, disco, corte);

    canvas.drawPath(
      solLuna,
      Paint()
        ..color = Color.lerp(
          UctPalette.amarillo,
          UctPalette.textoPrincipalOscuro,
          themeProgress,
        )!,
    );
  }

  Offset _puntoCuadratico(Offset inicio, Offset control, Offset fin, double t) {
    final inverso = 1 - t;
    return (inicio * (inverso * inverso)) +
        (control * (2 * inverso * t)) +
        (fin * (t * t));
  }

  @override
  bool shouldRepaint(_AuthBackdropPainter oldDelegate) =>
      oldDelegate.themeProgress != themeProgress;
}
