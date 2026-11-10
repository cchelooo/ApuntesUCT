import { Injectable } from '@nestjs/common';
import { randomBytes, scrypt } from 'node:crypto';

@Injectable()
export class PasswordHasher {
  async hash(password: string): Promise<string> {
    const salt = randomBytes(16);
    // scrypt N=2^17, r=8, p=1; asynchronous to avoid blocking the event loop.
    const key = await new Promise<Buffer>((resolve, reject) => {
      scrypt(
        password,
        salt,
        64,
        {
          N: 131072,
          r: 8,
          p: 1,
          maxmem: 256 * 1024 * 1024,
        },
        (error, derivedKey) => {
          if (error) reject(error);
          else resolve(derivedKey);
        },
      );
    });
    return `scrypt$131072$8$1$${salt.toString('hex')}$${key.toString('hex')}`;
  }
}
