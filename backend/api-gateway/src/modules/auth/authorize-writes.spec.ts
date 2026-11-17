import { ConfigService } from '@nestjs/config';
import type { Request, Response } from 'express';
import { sign } from 'jsonwebtoken';
import { authorizeWrites } from './authorize-writes';

describe('Jerarquía de permisos', () => {
  it.each([
    ['STUDENT', 'STUDENT', true],
    ['MODERATOR', 'STUDENT', true],
    ['ADMIN', 'STUDENT', true],
    ['STUDENT', 'MODERATOR', false],
    ['MODERATOR', 'MODERATOR', true],
    ['ADMIN', 'MODERATOR', true],
    ['STUDENT', 'ADMIN', false],
    ['MODERATOR', 'ADMIN', false],
    ['ADMIN', 'ADMIN', true],
  ] as const)('%s requiere %s: %s', (role, minimum, allowed) => {
    const middleware = authorizeWrites(
      new ConfigService({ JWT_ACCESS_SECRET: 'test-secret' }),
      minimum,
    );
    const token = sign(
      { sub: '11111111-1111-4111-8111-111111111111', role },
      'test-secret',
      { expiresIn: 60 },
    );
    const next = jest.fn();
    middleware(
      {
        method: 'POST',
        headers: { authorization: 'Bearer ' + token },
      } as Request,
      {} as Response,
      next,
    );
    if (allowed) expect(next).toHaveBeenCalledWith();
    else expect(next.mock.calls[0][0].getStatus()).toBe(403);
  });
});
