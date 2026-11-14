import { ConfigModule } from '@nestjs/config';
import { PasswordRecoveryService } from '../../application/auth/password-recovery.service';
import { PasswordRecoveryDelivery } from '../../infrastructure/notifications/password-recovery-delivery';
import { PasswordRecoveryController } from './password-recovery.controller';
import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { RegistrationController } from './registration.controller';
import { RegisterUserService } from '../../application/auth/register-user.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';

@Module({
  imports: [ConfigModule],
  controllers: [
    AuthController,
    RegistrationController,
    PasswordRecoveryController,
  ],
  providers: [
    RegisterUserService,
    PasswordHasher,
    PasswordRecoveryService,
    PasswordRecoveryDelivery,
  ],
})
export class AuthModule {}
