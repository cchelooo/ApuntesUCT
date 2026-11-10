import { Body, Controller, Post } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiConflictResponse,
  ApiCreatedResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { RegisterUserService } from '../../application/auth/register-user.service';
import { RegisterDto } from './dto/register.dto';
import { RegisterResponseDto } from './dto/register-response.dto';

@ApiTags('Auth')
@Controller('auth')
export class RegistrationController {
  constructor(private readonly users: RegisterUserService) {}

  @Post('register')
  @ApiOperation({
    summary: 'Registrar usuario institucional sin iniciar sesión',
  })
  @ApiCreatedResponse({ type: RegisterResponseDto })
  @ApiBadRequestResponse({
    description: 'Datos inválidos o dominio no institucional.',
  })
  @ApiConflictResponse({ description: 'El correo ya está registrado.' })
  register(@Body() input: RegisterDto): Promise<RegisterResponseDto> {
    return this.users.register(input);
  }
}
