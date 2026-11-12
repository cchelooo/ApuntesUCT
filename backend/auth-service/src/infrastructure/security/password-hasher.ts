import { Injectable } from '@nestjs/common';
import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

@Injectable()
export class PasswordHasher {
  async verify(password: string, encoded: string): Promise<boolean> {
    // Accept only the bounded parameters emitted by registration.
    const match =
      /^scrypt\$131072\$8\$1\$([a-f0-9]{32})\$([a-f0-9]{128})$/.exec(encoded);
    if (!match) return false;
    const key = await this.derive(password, Buffer.from(match[1], 'hex'));
    return timingSafeEqual(key, Buffer.from(match[2], 'hex'));
  }

  private derive(password: string, salt: Buffer): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      scrypt(
        password,
        salt,
        64,
        { N: 131072, r: 8, p: 1, maxmem: 256 * 1024 * 1024 },
        (error, key) => (error ? reject(error) : resolve(key)),
      );
    });
  }

  async hash(password: string): Promise<string> {
    const salt = randomBytes(16);
    const key = await this.derive(password, salt);
    return `scrypt$131072$8$1$${salt.toString('hex')}$${key.toString('hex')}`;
  }
}
