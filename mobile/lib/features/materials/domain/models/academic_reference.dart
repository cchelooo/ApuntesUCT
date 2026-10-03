/// Referencia lógica a una entidad académica de Catalog Service.
/// El nombre puede faltar hasta que Catalog proporcione los datos mostrados.
class AcademicReference {
  final String id;
  final String? name;

  AcademicReference({required this.id, this.name}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'No puede estar vacío.');
    }
    if (name != null && name!.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'No puede estar vacío.');
    }
  }

  /// Formato interno para fixtures; no define el DTO HTTP de Material Service.
  factory AcademicReference.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('La referencia académica requiere un ID.');
    }
    if (name != null && (name is! String || name.trim().isEmpty)) {
      throw const FormatException(
        'El nombre académico debe ser un texto válido.',
      );
    }

    return AcademicReference(id: id, name: name as String?);
  }

  Map<String, dynamic> toJson() => {'id': id, if (name != null) 'name': name};
}
