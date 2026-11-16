import { scrypt } from 'node:crypto';
import { PasswordHasher } from './password-hasher';

describe('PasswordHasher', () => {
  it('usa sal aleatoria y permite verificar la contraseña exacta con los parámetros almacenados', async () => {
    const hasher = new PasswordHasher();
    const password = ' contraseña con espacios ';
    const first = await hasher.hash(password);
    const second = await hasher.hash(password);
    expect(await hasher.verify(password, first)).toBe(true);
    expect(await hasher.verify(password.trim(), first)).toBe(false);
    expect(await hasher.verify(password, 'scrypt$999999999$8$1$bad$bad')).toBe(
      false,
    );
    expect(first).not.toBe(second);
    expect(first).not.toContain(password);
    const [algorithm, n, r, p, salt, digest] = first.split('$');
    expect(algorithm).toBe('scrypt');
    expect(salt).toHaveLength(32);
    const derive = (input: string) =>
      new Promise<Buffer>((resolve, reject) => {
        scrypt(
          input,
          Buffer.from(salt, 'hex'),
          64,
          {
            N: Number(n),
            r: Number(r),
            p: Number(p),
            maxmem: 256 * 1024 * 1024,
          },
          (error, key) => (error ? reject(error) : resolve(key)),
        );
      });
    expect((await derive(password)).toString('hex')).toBe(digest);
    expect((await derive(password.trim())).toString('hex')).not.toBe(digest);
  });
});
