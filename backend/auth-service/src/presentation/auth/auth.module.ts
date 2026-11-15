import { LoginService } from '../../application/auth/login.service';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';
import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { RegistrationController } from './registration.controller';
import { RegisterUserService } from '../../application/auth/register-user.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';

@Module({
  controllers: [AuthController, RegistrationController],
  providers: [
    RegisterUserService,
    PasswordHasher,
    LoginService,
    AccessTokenService,
  ],
})
export class AuthModule {}
