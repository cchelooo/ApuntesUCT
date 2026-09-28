import { AuthController } from './auth.controller';

describe('AuthController (login mock)', () => {
  let controller: AuthController;
  const credentials = {
    email: 'Estudiante@ALU.UCT.CL',
    password: 'clave-privada-de-prueba',
  };

  beforeEach(() => {
    controller = new AuthController();
    jest.spyOn(Date, 'now').mockReturnValue(1_800_000_000_999);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  function decodeToken(token: string) {
    const parts = token.split('.');
    expect(parts).toHaveLength(3);
    return {
      header: JSON.parse(
        Buffer.from(parts[0], 'base64url').toString(),
      ) as unknown,
      payload: JSON.parse(
        Buffer.from(parts[1], 'base64url').toString(),
      ) as unknown,
      signature: parts[2],
    };
  }

  it('devuelve el contrato de sesión y normaliza el correo sin modificar las credenciales', () => {
    const input = { ...credentials };
    const result = controller.login(input);

    expect(result).toEqual({
      accessToken: expect.any(String),
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: {
        id: '00000000-0000-4000-8000-000000000092',
        name: 'Estudiante de prueba',
        email: 'estudiante@alu.uct.cl',
        role: 'STUDENT',
        active: true,
      },
    });
    expect(input).toEqual(credentials);
  });

  it('genera un JWT explícitamente simulado, sin firma y con una hora de vigencia en segundos', () => {
    const result = controller.login(credentials);
    const token = decodeToken(result.accessToken);

    expect(token.header).toEqual({ alg: 'none', typ: 'JWT' });
    expect(token.signature).toBe('');
    expect(token.payload).toEqual({
      sub: result.user.id,
      email: result.user.email,
      role: 'STUDENT',
      iat: 1_800_000_000,
      exp: 1_800_003_600,
      mock: true,
    });
  });

  it('no expone la contraseña en la respuesta ni en el contenido decodificado del token', () => {
    const result = controller.login(credentials);
    const token = decodeToken(result.accessToken);

    for (const value of [result, token.header, token.payload]) {
      expect(value).not.toHaveProperty('password');
      expect(value).not.toHaveProperty('passwordHash');
      expect(JSON.stringify(value)).not.toContain(credentials.password);
    }
    expect(result.user).not.toHaveProperty('password');
    expect(result.user).not.toHaveProperty('passwordHash');
  });

  it('mantiene la identidad y el rol simulados aunque el cliente intente sobrescribirlos', () => {
    const result = controller.login({
      ...credentials,
      ...{ id: 'otro-usuario', role: 'ADMIN', active: false },
    });

    expect(result.user).toMatchObject({
      id: '00000000-0000-4000-8000-000000000092',
      role: 'STUDENT',
      active: true,
    });
    expect(decodeToken(result.accessToken).payload).toMatchObject({
      sub: result.user.id,
      role: 'STUDENT',
    });
  });
});
