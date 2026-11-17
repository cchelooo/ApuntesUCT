import { Body, Controller, Header, HttpCode, Post } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PasswordRecoveryService } from '../../application/auth/password-recovery.service';
import {
  ForgotPasswordDto,
  ResetPasswordDto,
} from './dto/password-recovery.dto';

@ApiTags('Auth')
@Controller('auth')
export class PasswordRecoveryController {
  constructor(private readonly recovery: PasswordRecoveryService) {}

  @Post('forgot-password')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Solicitar recuperación de contraseña' })
  @ApiOkResponse({
    description:
      'Respuesta genérica independiente de la existencia de la cuenta; no incluye token.',
  })
  @ApiBadRequestResponse({ description: 'Correo con formato inválido.' })
  request(@Body() input: ForgotPasswordDto) {
    return this.recovery.request(input.email);
  }

  @Post('reset-password')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Restablecer contraseña con token temporal de un solo uso',
  })
  @ApiOkResponse({
    description:
      'Contraseña actualizada; tokens de recuperación y refresh revocados.',
  })
  @ApiBadRequestResponse({
    description: 'Datos inválidos o token inválido, vencido o utilizado.',
  })
  reset(@Body() input: ResetPasswordDto) {
    return this.recovery.reset(input.token, input.password);
  }
}
