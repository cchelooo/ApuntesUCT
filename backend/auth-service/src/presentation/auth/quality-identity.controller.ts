import { ApiExcludeController } from '@nestjs/swagger';
import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  ServiceUnavailableException,
} from '@nestjs/common';
import { IsString } from 'class-validator';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';
import {
  fault,
  verifyService,
} from '../../infrastructure/moderation/service-assertion';
class IdentityRequest {
  @IsString() accessToken!: string;
}
@ApiExcludeController()
@Controller('internal/v1/quality')
export class QualityIdentityController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: AccessTokenService,
  ) {}
  @Post('identity')
  @HttpCode(200)
  async identity(
    @Body() body: IdentityRequest,
    @Headers('authorization') authorization?: string,
  ) {
    const context = verifyService(
      authorization,
      process.env.QUALITY_SERVICE_PUBLIC_KEY,
      'auth-service',
      'auth:identity:read',
      '/internal/v1/quality/identity',
      body,
    );
    const claims = this.tokens.verify(body.accessToken);
    if (claims.sub!.toLowerCase() !== context.actorId)
      throw fault(401, 'UNAUTHENTICATED', 'Identidad no coincidente.');
    let user;
    try {
      user = await this.prisma.user.findUnique({
        where: { id: claims.sub },
        select: { id: true, role: true, active: true, tokenVersion: true },
      });
    } catch {
      throw new ServiceUnavailableException(
        'No se pudo verificar la identidad.',
      );
    }
    if (!user) throw fault(401, 'UNAUTHENTICATED', 'Identidad no disponible.');
    const version = claims.tokenVersion ?? 0;
    if (!Number.isInteger(version) || version !== user.tokenVersion)
      throw fault(401, 'UNAUTHENTICATED', 'Credencial revocada.');
    if (!user.active) throw fault(403, 'FORBIDDEN', 'Cuenta inactiva.');
    return { id: user.id, role: user.role, active: true };
  }
}
