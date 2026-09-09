import 'package:flutter/material.dart';

import 'uct_palette.dart';

/// Los dos temas de la aplicación, construidos sobre la paleta institucional.
///
/// - **Claro** — dirección "Celeste claro": blanco y celeste, mucho aire,
///   campos rellenos con esquinas redondeadas y subrayado azul, botón píldora.
/// - **Oscuro** — dirección "Navy nocturno": el navy del sitio como superficie,
///   campos elevados con borde, y el amarillo institucional en el botón, que
///   pasa a ser lo único brillante de la pantalla.
///
/// No son dos diseños distintos sino el mismo, expresado en dos brillos. Todo
/// lo que cambia entre uno y otro vive acá: ninguna pantalla decide colores por
/// su cuenta, y por eso agregar una pantalla nueva no obliga a repetir esta
/// tabla.
abstract final class AppTheme {
  /// Radio de los campos de texto en modo claro.
  static const double _radioCampoClaro = 12;

  /// Radio de los campos de texto en modo oscuro.
  static const double _radioCampoOscuro = 10;

  /// Alto mínimo de los controles. Por debajo de 44 el dedo falla.
  static const double alturaControl = 54;

  // ---------------------------------------------------------------- claro ---

  /// Esquema de color del modo claro.
  static final ColorScheme _esquemaClaro =
      ColorScheme.fromSeed(
        seedColor: UctPalette.azul,
        brightness: Brightness.light,
      ).copyWith(
        primary: UctPalette.azul,
        onPrimary: Colors.white,
        // El amarillo institucional entra como secundario: subraya enlaces y marca
        // el acento decorativo, sin competir con el botón principal.
        secondary: UctPalette.amarillo,
        onSecondary: UctPalette.navy,
        surface: Colors.white,
        onSurface: UctPalette.navy,
        onSurfaceVariant: UctPalette.textoSuaveClaro,
        surfaceContainerHighest: UctPalette.humo,
        outline: UctPalette.bordeClaro,
        outlineVariant: UctPalette.celesteClaro,
        error: UctPalette.errorClaro,
        onError: Colors.white,
        errorContainer: UctPalette.errorFondoClaro,
        onErrorContainer: UctPalette.errorTextoClaro,
      );

  // --------------------------------------------------------------- oscuro ---

  /// Esquema de color del modo oscuro.
  static final ColorScheme _esquemaOscuro =
      ColorScheme.fromSeed(
        seedColor: UctPalette.amarillo,
        brightness: Brightness.dark,
      ).copyWith(
        // En oscuro el amarillo pasa a primario: es el color de marca y el único
        // que sobrevive al navy sin perder fuerza.
        primary: UctPalette.amarillo,
        onPrimary: UctPalette.navy,
        secondary: UctPalette.celeste,
        onSecondary: UctPalette.navy,
        surface: UctPalette.navy,
        onSurface: Colors.white,
        onSurfaceVariant: UctPalette.textoSuaveOscuro,
        surfaceContainerHighest: UctPalette.navyElevado,
        outline: UctPalette.navyBorde,
        outlineVariant: UctPalette.navyBorde,
        error: UctPalette.errorOscuro,
        onError: UctPalette.navy,
        errorContainer: UctPalette.errorFondoOscuro,
        onErrorContainer: UctPalette.errorTextoOscuro,
      );

  /// Tema del modo claro.
  static ThemeData get claro => _construir(
    esquema: _esquemaClaro,
    radioCampo: _radioCampoClaro,
    // Píldora: la forma que distingue al modo claro.
    formaBoton: const StadiumBorder(),
    // Relleno + subrayado grueso, sin caja completa.
    bordeCampo: (color, grosor) => UnderlineInputBorder(
      borderRadius: BorderRadius.circular(_radioCampoClaro),
      borderSide: BorderSide(color: color, width: grosor),
    ),
    colorSubrayadoCampo: UctPalette.azul,
    colorBordeCampoInactivo: UctPalette.azul,
    // El amarillo institucional es ilegible sobre blanco (1,7:1), así que
    // en claro los enlaces van en azul. El amarillo se reserva para el
    // acento decorativo, donde no tiene que leerse.
    colorEnlace: UctPalette.azul,
  );

  /// Tema del modo oscuro.
  static ThemeData get oscuro => _construir(
    esquema: _esquemaOscuro,
    radioCampo: _radioCampoOscuro,
    formaBoton: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radioCampoOscuro),
    ),
    // Caja completa: sobre el navy, un solo subrayado no delimita el campo.
    bordeCampo: (color, grosor) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radioCampoOscuro),
      borderSide: BorderSide(color: color, width: grosor),
    ),
    colorSubrayadoCampo: UctPalette.celeste,
    colorBordeCampoInactivo: UctPalette.navyBorde,
    colorEnlace: UctPalette.celeste,
  );

  /// Arma el tema completo a partir de lo que distingue a cada modo.
  static ThemeData _construir({
    required ColorScheme esquema,
    required double radioCampo,
    required OutlinedBorder formaBoton,
    required InputBorder Function(Color color, double grosor) bordeCampo,
    required Color colorSubrayadoCampo,
    required Color colorBordeCampoInactivo,
    required Color colorEnlace,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: esquema.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: esquema.onSurface,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: esquema.onSurfaceVariant,
        suffixIconColor: esquema.onSurfaceVariant,
        labelStyle: TextStyle(color: esquema.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorSubrayadoCampo),
        hintStyle: TextStyle(
          color: esquema.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: bordeCampo(colorBordeCampoInactivo, 1.5),
        enabledBorder: bordeCampo(colorBordeCampoInactivo, 1.5),
        focusedBorder: bordeCampo(colorSubrayadoCampo, 2),
        errorBorder: bordeCampo(esquema.error, 1.5),
        focusedErrorBorder: bordeCampo(esquema.error, 2),
        disabledBorder: bordeCampo(
          colorBordeCampoInactivo.withValues(alpha: 0.5),
          1.5,
        ),
        errorStyle: TextStyle(color: esquema.error, fontSize: 12),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: esquema.primary,
          foregroundColor: esquema.onPrimary,
          disabledBackgroundColor: esquema.primary.withValues(alpha: 0.55),
          disabledForegroundColor: esquema.onPrimary.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(alturaControl),
          shape: formaBoton,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorEnlace,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: esquema.onSurfaceVariant),
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.12,
        ),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      ).apply(bodyColor: esquema.onSurface, displayColor: esquema.onSurface),
    );
  }
}
