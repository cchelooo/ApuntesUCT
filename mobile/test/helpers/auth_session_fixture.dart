import 'dart:convert';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';

/// Controlled claims, NOT a cryptographically signed server credential.
Map<String, dynamic> loginFixture({
  String email = 'estudiante@alu.uct.cl',
  String name = 'Estudiante de prueba',
  String role = 'STUDENT',
  DateTime? now,
  Duration lifetime = const Duration(hours: 1),
}) {
  final issued = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final user = {
    'id': '00000000-0000-4000-8000-000000000092',
    'name': name,
    'email': email,
    'role': role,
    'active': true,
  };
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'accessToken':
        '${part({'alg': 'RS256', 'typ': 'JWT'})}.${part({'sub': user['id'], 'email': email, 'role': role, 'iat': issued, 'exp': issued + lifetime.inSeconds})}.Y29udHJvbGxlZC1zaWduYXR1cmU',
    'tokenType': 'Bearer',
    'expiresIn': lifetime.inSeconds,
    'user': user,
  };
}

/// Explicit authenticated state for existing layout/navigation fixture tests.
class AuthenticatedFixture extends AuthStateNotifier {
  @override
  Future<UserModel?> build() async => UserModel.mock();
}
