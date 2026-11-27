import { generateKeyPairSync, randomUUID } from 'node:crypto';
import { sign } from 'jsonwebtoken';
import { serviceToken, verifyService, digest } from './service-assertion';
describe('Perfil interno de Quality', () => {
  const pair = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const key = pair.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const pub = pair.publicKey.export({ type: 'spki', format: 'pem' }).toString();
  const actor = { id: randomUUID(), role: 'MODERATOR', authorizedAt: new Date().toISOString() };
  const body = { action: 'APPROVE', expectedRevision: 1 };
  const resource = '/internal/v1/quality/materials/a';
  const token = () =>
    serviceToken(
      key,
      'material-service',
      'material:quality:apply',
      resource,
      actor,
      body,
      randomUUID(),
    );
  it('verifica identidad de servicio, actor y cuerpo', () =>
    expect(
      verifyService(
        'Bearer ' + token(),
        pub,
        'material-service',
        'material:quality:apply',
        resource,
        body,
      ).actorId,
    ).toBe(actor.id));
  it.each(['audience', 'scope', 'resource', 'body', 'key'])('rechaza %s incompatible', (which) =>
    expect(() =>
      verifyService(
        'Bearer ' + token(),
        which === 'key' ? undefined : pub,
        which === 'audience' ? 'auth-service' : 'material-service',
        which === 'scope' ? 'read' : 'material:quality:apply',
        which === 'resource' ? '/other' : resource,
        which === 'body' ? {} : body,
      ),
    ).toThrow(),
  );
  it('rechaza JWT de usuario firmado con otra clave y un Bearer arbitrario', () => {
    const other = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const user = sign({ sub: actor.id, role: 'ADMIN' }, other.privateKey, {
      algorithm: 'RS256',
      expiresIn: 60,
    });
    for (const t of [user, 'abc'])
      expect(() =>
        verifyService(
          'Bearer ' + t,
          pub,
          'material-service',
          'material:quality:apply',
          resource,
          body,
        ),
      ).toThrow();
  });
  it('la huella no depende del orden JSON', () =>
    expect(digest({ b: 2, a: 1 })).toBe(digest({ a: 1, b: 2 })));
});
