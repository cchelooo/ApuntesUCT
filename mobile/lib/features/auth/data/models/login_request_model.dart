/// Cuerpo de la petición `POST /auth/login`.
///
/// Existe como modelo, y no como un mapa suelto, para que el contrato de la
/// petición quede en un solo lugar y un cambio del backend se refleje en un
/// único archivo.
class LoginRequestModel {
  final String email;
  final String password;

  const LoginRequestModel({required this.email, required this.password});

  /// Serializa el modelo al cuerpo JSON que espera la API.
  ///
  /// Normaliza el correo a minúsculas y sin espacios: el usuario escribe en un
  /// teclado móvil con autocapitalización y el backend compara el correo tal
  /// cual llega.
  Map<String, dynamic> toJson() {
    return {'email': email.trim().toLowerCase(), 'password': password};
  }

  /// Factory para generar una instancia MOCK de ejemplo.
  factory LoginRequestModel.mock({
    String email = 'marcelo.henriquez@uct.cl',
    String password = 'Apuntes2026',
  }) {
    return LoginRequestModel(email: email, password: password);
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  LoginRequestModel copyWith({String? email, String? password}) {
    return LoginRequestModel(
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginRequestModel &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          password == other.password;

  @override
  int get hashCode => email.hashCode ^ password.hashCode;

  /// Representación segura: nunca expone la contraseña.
  @override
  String toString() => 'LoginRequestModel(email: $email, password: <oculto>)';
}
