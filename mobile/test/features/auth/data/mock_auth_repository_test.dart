import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';

void main() {
  const repository = MockAuthRepository(simulatedDelay: Duration.zero);

  test('el login mock genera el nombre sin puntos ni espacios', () async {
    final user = await repository.login(
      email: 'marcelo.santana2023@alu.uct.cl',
      password: 'Password1',
    );

    expect(user.name, 'MARCELOSANTANA2023');
    expect(user.email, 'marcelo.santana2023@alu.uct.cl');
  });

  test('el login mock conserva nombres de usuario sin puntos', () async {
    final user = await repository.login(
      email: 'jperez2020@alu.uct.cl',
      password: 'Password1',
    );

    expect(user.name, 'JPEREZ2020');
  });
}
