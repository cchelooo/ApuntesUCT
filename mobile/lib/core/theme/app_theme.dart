import 'package:flutter/material.dart';

import 'uct_palette.dart';

/// Los dos temas de la aplicación, construidos sobre la paleta institucional.
///
/// - **Claro** — dirección "Celeste claro": blanco y celeste, mucho aire,
///   campos rellenos con esquinas redondeadas y acción principal azul.
/// - **Oscuro** — dirección "Carbón UCT": superficies neutras casi negras,
///   celeste para interacción y amarillo institucional para la acción principal.
///
/// No son dos diseños distintos sino el mismo, expresado en dos brillos. Todo
/// lo que cambia entre uno y otro vive acá: ninguna pantalla decide colores por
/// su cuenta, y por eso agregar una pantalla nueva no obliga a repetir esta
/// tabla.
abstract final class AppTheme {
  /// La geometría no cambia con el brillo: el tema sólo reemplaza colores.
  static const double _radioControl = 12;

  static final OutlinedBorder _formaBoton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radioControl),
  );

  static InputBorder _bordeCampo(Color color, double grosor) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radioControl),
        borderSide: BorderSide(color: color, width: grosor),
      );

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
        // En oscuro el amarillo pasa a primario para que la acción principal
        // conserve la marca sobre las superficies neutras.
        primary: UctPalette.amarillo,
        onPrimary: UctPalette.fondoOscuro,
        secondary: UctPalette.celeste,
        onSecondary: UctPalette.fondoOscuro,
        tertiary: UctPalette.azul,
        onTertiary: Colors.white,
        surface: UctPalette.fondoOscuro,
        onSurface: UctPalette.textoPrincipalOscuro,
        onSurfaceVariant: UctPalette.textoSuaveOscuro,
        surfaceContainerLowest: UctPalette.fondoOscuro,
        surfaceContainerLow: UctPalette.superficieOscura,
        surfaceContainer: UctPalette.superficieOscura,
        surfaceContainerHigh: UctPalette.superficieElevadaOscura,
        surfaceContainerHighest: UctPalette.superficieElevadaOscura,
        outline: UctPalette.bordeOscuro,
        outlineVariant: UctPalette.bordeOscuro,
        error: UctPalette.errorOscuro,
        onError: UctPalette.fondoOscuro,
        errorContainer: UctPalette.errorFondoOscuro,
        onErrorContainer: UctPalette.errorTextoOscuro,
      );

  /// Tema del modo claro.
  static ThemeData get claro => _construir(
    esquema: _esquemaClaro,
    formaBoton: _formaBoton,
    bordeCampo: _bordeCampo,
    colorSubrayadoCampo: UctPalette.azul,
    colorBordeCampoInactivo: UctPalette.bordeClaro,
    // El amarillo institucional es ilegible sobre blanco (1,7:1), así que
    // en claro los enlaces van en azul. El amarillo se reserva para el
    // acento decorativo, donde no tiene que leerse.
    colorEnlace: UctPalette.azul,
  );

  /// Tema del modo oscuro.
  static ThemeData get oscuro => _construir(
    esquema: _esquemaOscuro,
    formaBoton: _formaBoton,
    bordeCampo: _bordeCampo,
    colorSubrayadoCampo: UctPalette.celeste,
    colorBordeCampoInactivo: UctPalette.bordeOscuro,
    colorEnlace: UctPalette.celeste,
  );

  /// Arma el tema completo a partir de lo que distingue a cada modo.
  static ThemeData _construir({
    required ColorScheme esquema,
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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: esquema.primary,
          minimumSize: const Size(0, alturaControl),
          shape: formaBoton,
          side: BorderSide(color: esquema.primary, width: 1.5),
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

      dividerTheme: DividerThemeData(
        color: esquema.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      cardTheme: CardThemeData(
        color: esquema.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: esquema.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: esquema.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esquema.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: esquema.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),

      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.12,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ).apply(bodyColor: esquema.onSurface, displayColor: esquema.onSurface),
    );
  }
}
