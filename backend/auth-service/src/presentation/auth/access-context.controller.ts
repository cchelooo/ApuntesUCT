import { Controller, Get, Header, Headers, UnauthorizedException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

/** Consulta de identidad propia: nunca acepta un userId o rol libre. */
@ApiTags('Auth')
@ApiBearerAuth()
@Controller('auth')
export class AccessContextController {
  constructor(private readonly tokens: AccessTokenService, private readonly prisma: PrismaService) {}

  @Get('access-context')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Consultar identidad vigente del portador del JWT' })
  async get(@Headers('authorization') authorization?: string) {
    const match = /^Bearer\s+(\S+)$/i.exec(authorization ?? '');
    if (!match) throw new UnauthorizedException();
    const claims = this.tokens.verify(match[1]);
    const version: unknown = claims.tokenVersion ?? 0;
    if (!Number.isSafeInteger(version) || (version as number) < 0) throw new UnauthorizedException();
    let user;
    try {
      user = await this.prisma.user.findUnique({ where: { id: claims.sub }, select: { id: true, role: true, active: true, tokenVersion: true } });
    } catch { throw new ServiceUnavailableException('Identidad temporalmente no disponible.'); }
    if (!user || version !== user.tokenVersion) throw new UnauthorizedException();
    if (!user.active) throw new ForbiddenException('Cuenta inactiva.');
    return { id: user.id, role: user.role, active: true };
  }
}
