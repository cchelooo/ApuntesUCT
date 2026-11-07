import { validateEnvironment } from './configuration';
const DATABASE_URL = 'postgresql://test:test@127.0.0.1:5434/quality_db';

describe('Quality configuration', () => {
  it('usa el puerto reservado 3004 por defecto', () => {
    expect(validateEnvironment({ DATABASE_URL })).toEqual({
      port: 3004,
      databaseUrl: DATABASE_URL,
    });
  });
  it('permite un puerto de despliegue explícito', () => {
    expect(validateEnvironment({ DATABASE_URL, PORT: '4004' }).port).toBe(4004);
  });
  it.each(['0', '-1', '65536', '3004x', '', '3.5'])('rechaza PORT=%j', (PORT) => {
    expect(() => validateEnvironment({ DATABASE_URL, PORT })).toThrow('PORT');
  });
  it.each([undefined, '', '   '])('exige DATABASE_URL=%j', (value) => {
    expect(() => validateEnvironment({ DATABASE_URL: value })).toThrow('DATABASE_URL');
  });
  it.each([
    'not-a-url',
    'https://example.com/quality_db',
    'postgresql://localhost/material_db',
    'postgresql://localhost/auth_db',
    'postgresql://localhost/catalog_db',
  ])('rechaza una conexión ajena o inválida %s', (value) => {
    expect(() => validateEnvironment({ DATABASE_URL: value })).toThrow();
  });
  it('no expone credenciales en el error de validación', () => {
    expect(() =>
      validateEnvironment({ DATABASE_URL: 'postgresql://test:secret@localhost/material_db' }),
    ).toThrow('Quality Service debe conectarse a la base quality_db.');
  });
});
