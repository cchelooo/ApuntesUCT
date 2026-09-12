/// Cuerpo de la petición `POST /auth/register`.
///
/// El registro está restringido a correos institucionales `@uct.cl` y
/// `@alu.uct.cl` (RF-01). Esa regla la valida el backend; el formulario la
/// aplica antes de enviar sólo para evitar un viaje de red innecesario.
class RegisterRequestModel {
  final String name;
  final String email;
  final String password;

  const RegisterRequestModel({
    required this.name,
    required this.email,
    required this.password,
  });

  /// Serializa el modelo al cuerpo JSON que espera la API.
  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    };
  }

  /// Factory para generar una instancia MOCK de ejemplo.
  factory RegisterRequestModel.mock({
    String name = 'Camila Soto',
    String email = 'camila.soto@alu.uct.cl',
    String password = 'Apuntes2026',
  }) {
    return RegisterRequestModel(name: name, email: email, password: password);
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  RegisterRequestModel copyWith({
    String? name,
    String? email,
    String? password,
  }) {
    return RegisterRequestModel(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterRequestModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          email == other.email &&
          password == other.password;

  @override
  int get hashCode => name.hashCode ^ email.hashCode ^ password.hashCode;

  /// Representación segura: nunca expone la contraseña.
  @override
  String toString() =>
      'RegisterRequestModel(name: $name, email: $email, password: <oculto>)';
}
