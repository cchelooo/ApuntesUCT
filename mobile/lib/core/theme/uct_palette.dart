import 'package:flutter/material.dart';

/// Paleta institucional de la Universidad Católica de Temuco.
///
/// El amarillo, el azul y el celeste se tomaron del logo y de las variables CSS
/// de los sitios oficiales. Los grises son tokens propios de ApuntesUCT: crean
/// un modo oscuro neutro sin convertir el navy institucional en fondo dominante.
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

  /// Azul profundo de apoyo para titulares y contrastes de marca.
  static const Color navy = Color(0xFF0F1D34);

  // --- Colores complementarios para asignaturas y tarjetas -----------------

  /// Verde institucional / académico para tarjetas de cursos.
  static const Color verde = Color(0xFF2F8F73);

  /// Verde con contraste equilibrado para tarjetas en modo oscuro.
  static const Color verdeOscuro = Color(0xFF1B5C49);

  /// Ámbar / dorado para acentos de tarjetas, estrellas y doblez decorativo.
  static const Color dorado = Color(0xFFEAA83A);

  /// Ámbar con contraste equilibrado para tarjetas en modo oscuro.
  static const Color doradoOscuro = Color(0xFF805E00);

  /// Azul equilibrado para tarjetas en modo oscuro.
  static const Color azulTarjetaOscura = Color(0xFF154C79);

  // --- Superficies oscuras -------------------------------------------------

  /// Carbón casi negro. Fondo principal del modo oscuro.
  static const Color fondoOscuro = Color(0xFF0E1114);

  /// Grafito para tarjetas, barras y superficies contenidas.
  static const Color superficieOscura = Color(0xFF15191D);

  /// Grafito elevado para campos, diálogos y decoración.
  static const Color superficieElevadaOscura = Color(0xFF1D2329);

  /// Borde neutro para separar controles sin teñir toda la pantalla de azul.
  static const Color bordeOscuro = Color(0xFF343B43);

  /// Humo azulado. Relleno de los campos en modo claro.
  static const Color humo = Color(0xFFF3F7FA);

  /// Borde de los campos en modo claro.
  static const Color bordeClaro = Color(0xFFDCE7F0);

  /// Texto secundario en modo claro.
  static const Color textoSuaveClaro = Color(0xFF5B7089);

  /// Texto secundario en modo oscuro.
  static const Color textoSuaveOscuro = Color(0xFFB4BEC8);

  /// Blanco suave para texto principal e iconografía en modo oscuro.
  static const Color textoPrincipalOscuro = Color(0xFFF4F7FA);

  /// Etiquetas y texto terciario en modo oscuro.
  static const Color textoTenueOscuro = Color(0xFF89949F);

  /// Texto secundario que acompaña al dominio y al icono de contraseña.
  static const Color textoCampoClaro = Color(0xFF8CA3B8);
  static const Color textoCampoOscuro = Color(0xFF89949F);

  // --- Errores -------------------------------------------------------------

  /// Rojo de error en modo claro.
  static const Color errorClaro = Color(0xFFC62828);

  /// Fondo del banner de error en modo claro.
  static const Color errorFondoClaro = Color(0xFFFDF0F0);

  /// Borde del banner de error en modo claro.
  static const Color errorBordeClaro = Color(0xFFF0C9C9);

  /// Texto del banner de error en modo claro.
  static const Color errorTextoClaro = Color(0xFF9B1C1C);

  /// Rojo de error en modo oscuro, aclarado para que contraste con el carbón.
  static const Color errorOscuro = Color(0xFFFF9A9A);

  /// Fondo del banner de error en modo oscuro.
  static const Color errorFondoOscuro = Color(0xFF3A1A22);

  /// Borde del banner de error en modo oscuro.
  static const Color errorBordeOscuro = Color(0xFF7E3440);

  /// Texto del banner de error en modo oscuro.
  static const Color errorTextoOscuro = Color(0xFFFFC7C7);
}
