import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { LoginDto } from './login.dto';

describe('LoginDto (validación de entrada)', () => {
  const validCredentials = {
    email: 'estudiante@alu.uct.cl',
    password: 'demo',
  };
  let pipe: ValidationPipe;

  beforeEach(() => {
    // Misma configuración que main.ts, sin levantar HTTP ni una base de datos.
    pipe = new ValidationPipe({ whitelist: true, transform: true });
  });

  function validate(body: unknown): Promise<LoginDto> {
    return pipe.transform(body, {
      type: 'body',
      metatype: LoginDto,
    }) as Promise<LoginDto>;
  }

  it.each(['demo', ' clave con espacios ', 'a'])(
    'acepta una contraseña no vacía sin imponer reglas ajenas al mock: %j',
    async (password) => {
      const body = { ...validCredentials, password };
      const result = await validate(body);

      expect(result).toBeInstanceOf(LoginDto);
      expect(result).toEqual(body);
    },
  );

  it.each([undefined, null, '', 'invalido', 'usuario@', 123, {}, []])(
    'rechaza un correo ausente, mal formado o de tipo incorrecto: %j',
    async (email) => {
      await expect(validate({ ...validCredentials, email })).rejects.toThrow(
        BadRequestException,
      );
    },
  );

  it.each([
    undefined,
    null,
    '',
    '   ',
    '\t',
    '\n',
    ' \t\r\n ',
    '\u00a0',
    123,
    true,
    {},
    [],
  ])(
    'rechaza una contraseña ausente, en blanco o de tipo incorrecto: %j',
    async (password) => {
      await expect(validate({ ...validCredentials, password })).rejects.toThrow(
        BadRequestException,
      );
    },
  );

  it.each([undefined, null, {}])(
    'rechaza un cuerpo sin credenciales: %j',
    async (body) => {
      await expect(validate(body)).rejects.toThrow(BadRequestException);
    },
  );

  it('elimina campos no permitidos para que el cliente no controle la identidad o los privilegios', async () => {
    const result = await validate({
      ...validCredentials,
      id: 'otro-usuario',
      role: 'ADMIN',
      active: true,
      accessToken: 'token-inyectado',
    });

    expect(result).toEqual(validCredentials);
  });
});
