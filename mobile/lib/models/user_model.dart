/// Modelo inmutable que representa a un usuario autenticado en el sistema.
/// Mapea la entidad USER proveniente de Auth Service a través del API Gateway.
///
/// Nota de seguridad: No contiene credenciales ni passwordHash.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  /// Serializa el modelo a un mapa JSON para envío o persistencia.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'active': active,
    };
  }

  /// Factory para generar una instancia MOCK para pruebas de UI y estado sin backend.
  factory UserModel.mock({
    String id = 'a8098c1a-f86e-11da-bd1a-00112444be1e',
    String name = 'Marcelo Henríquez',
    String email = 'marcelo.henriquez@uct.cl',
    String role = 'STUDENT',
    bool active = true,
  }) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      role: role,
      active: active,
    );
  }

  /// Lista de usuarios MOCK de ejemplo para testing y prototipos.
  static List<UserModel> mockList() {
    return [
      UserModel.mock(
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Marcelo Henríquez',
        email: 'marcelo.henriquez@uct.cl',
        role: 'STUDENT',
        active: true,
      ),
      UserModel.mock(
        id: '22222222-2222-2222-2222-222222222222',
        name: 'Camila Soto',
        email: 'camila.soto@uct.cl',
        role: 'STUDENT',
        active: true,
      ),
      UserModel.mock(
        id: '33333333-3333-3333-3333-333333333333',
        name: 'Prof. Nelson Mellado',
        email: 'nmellado@uct.cl',
        role: 'PROFESSOR',
        active: true,
      ),
      UserModel.mock(
        id: '44444444-4444-4444-4444-444444444444',
        name: 'Administrador UCT',
        email: 'admin@uct.cl',
        role: 'ADMIN',
        active: true,
      ),
    ];
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? active,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          active == other.active;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      role.hashCode ^
      active.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role, active: $active)';
  }
}
