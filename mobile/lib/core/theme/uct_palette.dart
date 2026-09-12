import 'package:flutter/material.dart';

/// Paleta institucional de la Universidad Católica de Temuco.
///
/// Los valores no son una interpretación: se tomaron de los sitios oficiales.
/// El amarillo y el azul salen del muestreo de píxeles del logo y de las
/// variables CSS de `www.uct.cl`; el azul oscuro es el dominante en
/// `estudiantes.uct.cl`.
///
/// Detalle que conviene tener presente: en la identidad de la UCT **el amarillo
/// es el color primario, no un acento** (`--primary` del sitio). Por eso en modo
/// oscuro el botón principal es amarillo y no azul.
abstract final class UctPalette {
  /// Amarillo institucional. `--primary` de uct.cl.
  static const Color amarillo = Color(0xFFFEC601);

  /// Amarillo del logo, medio tono más cálido. Se usa en estados presionados.
  static const Color amarilloLogo = Color(0xFFFFC000);

  /// Amarillo apagado para el estado "enviando" del botón.
  static const Color amarilloOscuro = Color(0xFFE3B101);

  /// Azul institucional. Botón principal en modo claro.
  static const Color azul = Color(0xFF0078BC);

  /// Azul oscuro, dominante en estudiantes.uct.cl. Titulares en modo claro.
  static const Color azulOscuro = Color(0xFF01568E);

  /// Celeste. `--secondary` de uct.cl. Enlaces en modo oscuro.
  static const Color celeste = Color(0xFF3DA5D9);

  /// Celeste muy claro, para el fondo decorativo del modo claro.
  static const Color celesteClaro = Color(0xFFE3F1FA);

  /// Celeste claro con un punto más de saturación.
  static const Color celesteTinte = Color(0xFFD2E9F7);

  /// Navy. Fondo dominante de uct.cl y superficie del modo oscuro.
  static const Color navy = Color(0xFF0F1D34);

  /// Navy elevado: relleno de campos y decoración en modo oscuro.
  static const Color navyElevado = Color(0xFF16294A);

  /// Borde de los campos en modo oscuro.
  static const Color navyBorde = Color(0xFF2A4570);

  /// Humo azulado. Relleno de los campos en modo claro.
  static const Color humo = Color(0xFFF3F7FA);

  /// Borde de los campos en modo claro.
  static const Color bordeClaro = Color(0xFFDCE7F0);

  /// Texto secundario en modo claro.
  static const Color textoSuaveClaro = Color(0xFF5B7089);

  /// Texto secundario en modo oscuro.
  static const Color textoSuaveOscuro = Color(0xFF9DB3CC);

  /// Etiquetas y texto terciario en modo oscuro.
  static const Color textoTenueOscuro = Color(0xFF7E97B5);

  /// Texto secundario que acompaña al dominio y al icono de contraseña.
  static const Color textoCampoClaro = Color(0xFF8CA3B8);
  static const Color textoCampoOscuro = Color(0xFF6B86A6);

  // --- Errores -------------------------------------------------------------

  /// Rojo de error en modo claro.
  static const Color errorClaro = Color(0xFFC62828);

  /// Fondo del banner de error en modo claro.
  static const Color errorFondoClaro = Color(0xFFFDF0F0);

  /// Borde del banner de error en modo claro.
  static const Color errorBordeClaro = Color(0xFFF0C9C9);

  /// Texto del banner de error en modo claro.
  static const Color errorTextoClaro = Color(0xFF9B1C1C);

  /// Rojo de error en modo oscuro, aclarado para que contraste con el navy.
  static const Color errorOscuro = Color(0xFFFF9A9A);

  /// Fondo del banner de error en modo oscuro.
  static const Color errorFondoOscuro = Color(0xFF3A1A22);

  /// Borde del banner de error en modo oscuro.
  static const Color errorBordeOscuro = Color(0xFF7E3440);

  /// Texto del banner de error en modo oscuro.
  static const Color errorTextoOscuro = Color(0xFFFFC7C7);
}
