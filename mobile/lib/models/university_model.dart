/// Modelo inmutable que representa una universidad en el catálogo académico.
/// Mapea la entidad UNIVERSITY proveniente de Catalog Service.
class UniversityModel {
  final String id;
  final String name;
  final String code;

  const UniversityModel({
    required this.id,
    required this.name,
    required this.code,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory UniversityModel.fromJson(Map<String, dynamic> json) {
    return UniversityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }

  /// Factory para generar una instancia MOCK para prototipado rápido.
  factory UniversityModel.mock({
    String id = 'uct-main-uuid',
    String name = 'Universidad Católica de Temuco',
    String code = 'UCT',
  }) {
    return UniversityModel(
      id: id,
      name: name,
      code: code,
    );
  }

  /// Lista de universidades MOCK para pruebas de UI y dropdowns/selectores.
  static List<UniversityModel> mockList() {
    return [
      UniversityModel.mock(
        id: 'uct-main-uuid',
        name: 'Universidad Católica de Temuco',
        code: 'UCT',
      ),
      UniversityModel.mock(
        id: 'ufro-main-uuid',
        name: 'Universidad de La Frontera',
        code: 'UFRO',
      ),
      UniversityModel.mock(
        id: 'uach-main-uuid',
        name: 'Universidad Austral de Chile',
        code: 'UACH',
      ),
    ];
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  UniversityModel copyWith({
    String? id,
    String? name,
    String? code,
  }) {
    return UniversityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UniversityModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ code.hashCode;

  @override
  String toString() {
    return 'UniversityModel(id: $id, name: $name, code: $code)';
  }
}
