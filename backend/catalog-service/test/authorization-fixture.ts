import { generateKeyPairSync } from 'node:crypto';
import { sign } from 'jsonwebtoken';
const keys = generateKeyPairSync('rsa', { modulusLength: 2048 });
export const jwtSettings = {
  JWT_ACCESS_PUBLIC_KEY: keys.publicKey
    .export({ type: 'spki', format: 'pem' })
    .toString(),
  JWT_ISSUER: 'test-auth',
  JWT_AUDIENCE: 'test-api',
};
export function accessToken(
  role = 'ADMIN',
  claims: Record<string, unknown> = {},
  wrongKey = false,
): string {
  return sign(
    { sub: '11111111-1111-4111-8111-111111111111', role, ...claims },
    wrongKey
      ? generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey
      : keys.privateKey,
    {
      algorithm: 'RS256',
      ...(claims.iss === undefined ? { issuer: jwtSettings.JWT_ISSUER } : {}),
      ...(claims.aud === undefined
        ? { audience: jwtSettings.JWT_AUDIENCE }
        : {}),
      ...(claims.exp === undefined ? { expiresIn: 300 } : {}),
    },
  );
}
