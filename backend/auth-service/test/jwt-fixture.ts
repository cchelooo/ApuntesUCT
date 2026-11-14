import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export function configureTestJwt() {
  const previous = { ...process.env };
  const directory = mkdtempSync(join(tmpdir(), 'auth-jwt-'));
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const path = join(directory, 'private.pem');
  writeFileSync(path, privateKey.export({ type: 'pkcs8', format: 'pem' }), {
    mode: 0o600,
  });
  process.env.JWT_PRIVATE_KEY_PATH = path;
  process.env.JWT_ISSUER = 'test-auth';
  process.env.JWT_AUDIENCE = 'test-api';
  return {
    privateKey,
    publicKey,
    cleanup() {
      for (const key of [
        'JWT_PRIVATE_KEY_PATH',
        'JWT_ISSUER',
        'JWT_AUDIENCE',
      ]) {
        if (previous[key] === undefined) delete process.env[key];
        else process.env[key] = previous[key];
      }
      rmSync(directory, { recursive: true, force: true });
    },
  };
}
