/// Utilidades de deserialización y validación estricta para respuestas de Quality Service.
///
/// Implementa reglas contractuales:
/// - UUIDs no vacíos.
/// - Manejo estricto de nulos sin inventar datos ficticios.
/// - Fechas en formato ISO 8601 UTC.
/// - Enteros y números no negativos con límites acordes a OpenAPI.
abstract final class QualityJson {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String requiredUuid(Map<String, dynamic> json, String key) {
    final value = requiredText(json, key);
    if (!_uuidRegex.hasMatch(value)) {
      throw FormatException('$key debe ser un UUID válido.');
    }
    return value;
  }

  static String? uuid(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    if (value == null) return null;
    if (!_uuidRegex.hasMatch(value)) {
      throw FormatException('$key debe ser un UUID válido.');
    }
    return value;
  }

  static int requiredInteger(
    Map<String, dynamic> json,
    String key, {
    int? min,
    int? max,
  }) {
    final value = integer(json, key, min: min, max: max);
    if (value == null) {
      throw FormatException('$key es un campo entero obligatorio.');
    }
    return value;
  }

  static int? integer(
    Map<String, dynamic> json,
    String key, {
    int? min,
    int? max,
  }) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw FormatException('$key debe ser un número entero.');
    }
    final intVal = value.toInt();
    if (min != null && intVal < min) {
      throw FormatException('$key debe ser mayor o igual a $min.');
    }
    if (max != null && intVal > max) {
      throw FormatException('$key debe ser menor o igual a $max.');
    }
    return intVal;
  }

  static double requiredNumber(
    Map<String, dynamic> json,
    String key, {
    double? min,
    double? max,
  }) {
    final value = number(json, key, min: min, max: max);
    if (value == null) {
      throw FormatException('$key es un número obligatorio.');
    }
    return value;
  }

  static double? number(
    Map<String, dynamic> json,
    String key, {
    double? min,
    double? max,
  }) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw FormatException('$key debe ser un número válido.');
    }
    final doubleVal = value.toDouble();
    if (min != null && doubleVal < min) {
      throw FormatException('$key debe ser mayor o igual a $min.');
    }
    if (max != null && doubleVal > max) {
      throw FormatException('$key debe ser menor o igual a $max.');
    }
    return doubleVal;
  }

  static bool requiredBoolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value is! bool) {
      throw FormatException('$key debe ser un booleano obligatorio.');
    }
    return value;
  }

  static bool? boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! bool) throw FormatException('$key debe ser un booleano.');
    return value;
  }

  static DateTime requiredTimestamp(Map<String, dynamic> json, String key) {
    final value = timestamp(json, key);
    if (value == null) {
      throw FormatException('$key es una fecha obligatoria.');
    }
    return value;
  }

  static DateTime? timestamp(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$key debe ser una fecha ISO 8601 válida.');
    }
    return parsed;
  }

  static List<T> list<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Object?) parse,
  ) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List) throw FormatException('$key debe ser una lista.');
    return value.map(parse).toList();
  }

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Se esperaba un objeto JSON.');
    }
    return value;
  }

  static Map<String, dynamic>? objectNullable(Object? value) {
    if (value == null) return null;
    return object(value);
  }
}
