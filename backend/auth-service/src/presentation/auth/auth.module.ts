import { AccessContextController } from './access-context.controller';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { RegistrationController } from './registration.controller';
import { PasswordRecoveryController } from './password-recovery.controller';
import { RegisterUserService } from '../../application/auth/register-user.service';
import { LoginService } from '../../application/auth/login.service';
import { PasswordRecoveryService } from '../../application/auth/password-recovery.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';
import { AccessTokenService } from '../../infrastructure/security/access-token.service';
import { PasswordRecoveryDelivery } from '../../infrastructure/notifications/password-recovery-delivery';

@Module({
  imports: [ConfigModule],
  controllers: [
    AccessContextController,
    AuthController,
    RegistrationController,
    PasswordRecoveryController,
  ],
  providers: [
    RegisterUserService,
    PasswordHasher,
    LoginService,
    AccessTokenService,
    PasswordRecoveryService,
    PasswordRecoveryDelivery,
  ],
})
export class AuthModule {}
