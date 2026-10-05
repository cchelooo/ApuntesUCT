import 'academic_reference.dart';

/// Lectura del formato interno de fixtures. El adaptador HTTP debe mapear
/// OpenAPI a este formato cuando se publique el contrato de INT2.
abstract final class MaterialJson {
  static String requiredText(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    if (value == null || value.trim().isEmpty) {
      throw FormatException('$key debe ser un texto no vacío.');
    }
    return value;
  }

  static String? text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key debe ser un texto.');
    return value;
  }

  static int? integer(Map<String, dynamic> json, String key, {int min = 0}) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num ||
        !value.isFinite ||
        value != value.roundToDouble() ||
        value < min) {
      throw FormatException('$key debe ser un entero mayor o igual a $min.');
    }
    return value.toInt();
  }

  static double? number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite || value < 0) {
      throw FormatException('$key debe ser un número no negativo.');
    }
    return value.toDouble();
  }

  static DateTime? timestamp(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$key debe ser una fecha ISO válida.');
    }
    final calendar = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (calendar != null) {
      final year = int.parse(calendar[1]!);
      final month = int.parse(calendar[2]!);
      final day = int.parse(calendar[3]!);
      final normalized = DateTime.utc(year, month, day);
      if (normalized.year != year ||
          normalized.month != month ||
          normalized.day != day) {
        throw FormatException('$key contiene una fecha inexistente.');
      }
    }
    return parsed;
  }

  static List<T> list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Object?) parse,
  ) {
    final value = json[key];
    if (value == null) return [];
    if (value is! List) throw FormatException('$key debe ser una lista.');
    return value.map(parse).toList();
  }

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Se esperaba un objeto JSON.');
    }
    return value;
  }

  static AcademicReference? reference(
    Map<String, dynamic> json,
    String idKey,
    String nameKey,
  ) {
    final id = text(json, idKey);
    if (id == null) return null;
    final name = text(json, nameKey);
    return AcademicReference.fromJson({
      'id': id,
      if (name != null && name.trim().isNotEmpty) 'name': name,
    });
  }
}
