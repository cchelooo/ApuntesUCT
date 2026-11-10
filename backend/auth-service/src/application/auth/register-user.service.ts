import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma } from '.prisma/auth-client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';

@Injectable()
export class RegisterUserService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
  ) {}

  async register(input: { name: string; email: string; password: string }) {
    const email = input.email.trim().toLowerCase();
    const passwordHash = await this.passwords.hash(input.password);
    try {
      const user = await this.prisma.user.create({
        data: { name: input.name.trim(), email, passwordHash, role: 'STUDENT' },
        select: { id: true, name: true, email: true, role: true, active: true },
      });
      return { user };
    } catch (error) {
      // The unique constraint also handles concurrent registrations.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('El correo ya está registrado');
      }
      throw error;
    }
  }
}
