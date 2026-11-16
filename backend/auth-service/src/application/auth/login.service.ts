import { Injectable, UnauthorizedException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';

@Injectable()
export class LoginService {
  // Same password derivation cost for unknown accounts, without a stored credential.
  private readonly dummyHash = `scrypt$131072$8$1$${randomBytes(16).toString('hex')}$${randomBytes(64).toString('hex')}`;

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
    private readonly tokens: AccessTokenService,
  ) {}

  async login(input: { email: string; password: string }) {
    const account = await this.prisma.user.findUnique({
      where: { email: input.email.trim().toLowerCase() },
    });
    const valid = await this.passwords.verify(
      input.password,
      account?.passwordHash ?? this.dummyHash,
    );
    if (!account || !valid || !account.active) {
      throw new UnauthorizedException('Credenciales inválidas');
    }
    const { id, name, email, role, active } = account;
    const user = { id, name, email, role, active };
    return {
      accessToken: this.tokens.issue(user),
      tokenType: 'Bearer',
      expiresIn: this.tokens.expiresIn,
      user,
    };
  }
}
