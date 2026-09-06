/// Modelo inmutable que representa una carrera académica dentro de una universidad.
/// Mapea la entidad CAREER proveniente de Catalog Service.
class CareerModel {
  final String id;
  final String universityId;
  final String name;
  final String code;
  final bool active;

  const CareerModel({
    required this.id,
    required this.universityId,
    required this.name,
    required this.code,
    required this.active,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory CareerModel.fromJson(Map<String, dynamic> json) {
    return CareerModel(
      id: json['id'] as String,
      universityId: json['universityId'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'universityId': universityId,
      'name': name,
      'code': code,
      'active': active,
    };
  }

  /// Factory para generar una instancia MOCK de ejemplo.
  factory CareerModel.mock({
    String id = 'inf-uct-uuid',
    String universityId = 'uct-main-uuid',
    String name = 'Ingeniería Civil en Informática',
    String code = 'ICI',
    bool active = true,
  }) {
    return CareerModel(
      id: id,
      universityId: universityId,
      name: name,
      code: code,
      active: active,
    );
  }

  /// Lista de carreras MOCK para poblar menús y catálogos.
  static List<CareerModel> mockList() {
    return [
      CareerModel.mock(
        id: 'inf-uct-uuid',
        universityId: 'uct-main-uuid',
        name: 'Ingeniería Civil en Informática',
        code: 'ICI',
        active: true,
      ),
      CareerModel.mock(
        id: 'ind-uct-uuid',
        universityId: 'uct-main-uuid',
        name: 'Ingeniería Civil Industrial',
        code: 'ICIND',
        active: true,
      ),
      CareerModel.mock(
        id: 'med-uct-uuid',
        universityId: 'uct-main-uuid',
        name: 'Medicina Veterinaria',
        code: 'MVET',
        active: true,
      ),
      CareerModel.mock(
        id: 'der-uct-uuid',
        universityId: 'uct-main-uuid',
        name: 'Derecho',
        code: 'DER',
        active: true,
      ),
    ];
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  CareerModel copyWith({
    String? id,
    String? universityId,
    String? name,
    String? code,
    bool? active,
  }) {
    return CareerModel(
      id: id ?? this.id,
      universityId: universityId ?? this.universityId,
      name: name ?? this.name,
      code: code ?? this.code,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CareerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          universityId == other.universityId &&
          name == other.name &&
          code == other.code &&
          active == other.active;

  @override
  int get hashCode =>
      id.hashCode ^
      universityId.hashCode ^
      name.hashCode ^
      code.hashCode ^
      active.hashCode;

  @override
  String toString() {
    return 'CareerModel(id: $id, universityId: $universityId, name: $name, code: $code, active: $active)';
  }
}
