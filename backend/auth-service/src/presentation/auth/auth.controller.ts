import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { LoginService } from '../../application/auth/login.service';
import { LoginDto } from './dto/login.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly loginService: LoginService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Inicio de sesión',
    description:
      'Verifica las credenciales de un usuario activo y devuelve un JWT firmado RS256.',
  })
  @ApiOkResponse({
    description: 'Sesión autenticada.',
    schema: {
      type: 'object',
      required: ['accessToken', 'tokenType', 'expiresIn', 'user'],
      properties: {
        accessToken: {
          type: 'string',
          description:
            'JWT firmado RS256 con identidad, rol, emisor, audiencia y expiración.',
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
    description:
      'Correo inválido o contraseña ausente, vacía o formada solo por espacios en blanco.',
  })
  @ApiUnauthorizedResponse({
    description: 'Credenciales inválidas o usuario inactivo.',
  })
  login(@Body() credentials: LoginDto) {
    return this.loginService.login(credentials);
  }
}
