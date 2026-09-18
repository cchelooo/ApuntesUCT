import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { LoginDto } from './dto/login.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Login mock temporal (#92)',
    description:
      'Acepta cualquier credencial con formato válido. Devuelve un JWT falso sin firma, solo para integración del frontend; no autentica usuarios.',
  })
  @ApiOkResponse({
    description:
      'Sesión simulada. El token no sirve para autorizar peticiones.',
    schema: {
      type: 'object',
      required: ['accessToken', 'tokenType', 'expiresIn', 'user'],
      properties: {
        accessToken: {
          type: 'string',
          description: 'JWT sin firma (alg: none), con claim mock: true.',
        },
        tokenType: { type: 'string', example: 'Bearer' },
        expiresIn: { type: 'integer', example: 3600 },
        user: {
          type: 'object',
          required: ['id', 'name', 'email', 'role', 'active'],
          properties: {
            id: {
              type: 'string',
              format: 'uuid',
              example: '00000000-0000-4000-8000-000000000092',
            },
            name: { type: 'string', example: 'Estudiante de prueba' },
            email: {
              type: 'string',
              format: 'email',
              example: 'estudiante@alu.uct.cl',
            },
            role: { type: 'string', example: 'STUDENT' },
            active: { type: 'boolean', example: true },
          },
        },
      },
    },
  })
  @ApiBadRequestResponse({
    description: 'Correo inválido o contraseña ausente/vacía.',
  })
  login(@Body() credentials: LoginDto) {
    const user = {
      id: '00000000-0000-4000-8000-000000000092',
      name: 'Estudiante de prueba',
      email: credentials.email.toLowerCase(),
      role: 'STUDENT',
      active: true,
    };
    const expiresIn = 3600;
    const issuedAt = Math.floor(Date.now() / 1000);
    const header = Buffer.from(
      JSON.stringify({ alg: 'none', typ: 'JWT' }),
    ).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({
        sub: user.id,
        email: user.email,
        role: user.role,
        iat: issuedAt,
        exp: issuedAt + expiresIn,
        mock: true,
      }),
    ).toString('base64url');

    // Temporal (#92): JWT deliberadamente sin firma; reemplazar por autenticación real.
    return {
      accessToken: `${header}.${payload}.`,
      tokenType: 'Bearer',
      expiresIn,
      user,
    };
  }
}
