import 'dart:convert';

import '../../features/auth/data/models/login_response_model.dart';
import '../../models/user_model.dart';

/// Local lifetime and identity checks; only the server verifies the JWT signature.
class AuthSession {
  final String accessToken;
  final UserModel user;
  final DateTime expiresAt;

  const AuthSession._(this.accessToken, this.user, this.expiresAt);

  factory AuthSession.fromLogin(Map<String, dynamic> json, DateTime now) {
    final response = LoginResponseModel.fromJson(json);
    final token = response.tokens.accessToken;
    final parts = token.split('.');
    if (parts.length != 3 ||
        parts.any((p) => p.isEmpty) ||
        response.tokens.tokenType != 'Bearer') {
      throw const FormatException('Credencial de sesión inválida.');
    }
    Map<String, dynamic> decode(String part) => Map<String, dynamic>.from(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))))
          as Map,
    );
    final header = decode(parts[0]);
    final claims = decode(parts[1]);
    final exp = claims['exp'];
    final issued = claims['iat'];
    final user = response.user;
    if (header['alg'] != 'RS256' ||
        claims.containsKey('mock') ||
        exp is! int ||
        issued is! int ||
        exp <= issued ||
        claims['sub'] != user.id ||
        claims['email'] != user.email ||
        claims['role'] != user.role ||
        !user.active ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(user.id) ||
        !['STUDENT', 'MODERATOR', 'ADMIN'].contains(user.role) ||
        user.name.trim().isEmpty ||
        !user.email.contains('@') ||
        json['user'] is! Map ||
        (json['user'] as Map)['active'] != true) {
      throw const FormatException('Identidad de sesión inválida.');
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    if (!expiresAt.isAfter(now.toUtc())) {
      throw const FormatException('La sesión ha vencido.');
    }
    return AuthSession._(token, user, expiresAt);
  }

  factory AuthSession.restore(String value, DateTime now) =>
      AuthSession.fromLogin(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
        now,
      );

  String encode() => jsonEncode({
    'accessToken': accessToken,
    'tokenType': 'Bearer',
    'user': user.toJson(),
  });

  @override
  String toString() => 'AuthSession(credentials: <ocultas>)';
}
