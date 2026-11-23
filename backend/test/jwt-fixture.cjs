const { generateKeyPairSync, randomUUID } = require('node:crypto');
const { sign } = require('jsonwebtoken');

// Claves efímeras por ejecución; la clave privada nunca sale de este closure.
function jwtFixture() {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const settings = {
    JWT_ACCESS_PUBLIC_KEY: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
    JWT_ISSUER: 'integration-auth',
    JWT_AUDIENCE: 'integration-api',
    JWT_ACCESS_SECRET: '',
    MATERIAL_LOCAL_AUTHOR_ENABLED: 'false',
  };
  return {
    settings,
    authorization(sub = randomUUID(), role = 'STUDENT', options = {}) {
      return 'Bearer ' + sign({ role, email: 'integration@alu.uct.cl' }, privateKey, {
        algorithm: 'RS256', subject: sub, issuer: settings.JWT_ISSUER,
        audience: settings.JWT_AUDIENCE, expiresIn: '15m', ...options,
      });
    },
  };
}
module.exports = { jwtFixture };
