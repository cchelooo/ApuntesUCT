/// Cuerpo de la petición `POST /auth/forgot-password`.
class ForgotPasswordRequestModel {
  final String email;

  const ForgotPasswordRequestModel({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email.trim().toLowerCase()};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgotPasswordRequestModel &&
          runtimeType == other.runtimeType &&
          email == other.email;

  @override
  int get hashCode => email.hashCode;

  @override
  String toString() => 'ForgotPasswordRequestModel(email: $email)';
}

/// Cuerpo de la petición `POST /auth/reset-password`.
class ResetPasswordRequestModel {
  final String token;
  final String password;

  const ResetPasswordRequestModel({
    required this.token,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token.trim().toLowerCase(),
      'password': password,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetPasswordRequestModel &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          password == other.password;

  @override
  int get hashCode => token.hashCode ^ password.hashCode;

  @override
  String toString() =>
      'ResetPasswordRequestModel(token: <oculto>, password: <oculto>)';
}
