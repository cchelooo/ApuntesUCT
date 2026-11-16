import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** Trusted notification gateway: it must deliver only to the supplied recipient. */
@Injectable()
export class PasswordRecoveryDelivery {
  constructor(private readonly config: ConfigService) {}

  async send(email: string, token: string, expiresAt: Date): Promise<void> {
    const endpoint = this.config.get<string>('PASSWORD_RECOVERY_DELIVERY_URL');
    const secret = this.config.get<string>('PASSWORD_RECOVERY_DELIVERY_SECRET');
    if (!endpoint || !secret) throw new Error('Recovery delivery unavailable');
    const url = new URL(endpoint);
    if (url.protocol !== 'https:' || url.username || url.password) {
      throw new Error('Recovery delivery requires HTTPS');
    }
    const response = await fetch(url, {
      method: 'POST',
      redirect: 'error',
      signal: AbortSignal.timeout(5000),
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'password-recovery',
        email,
        token,
        expiresAt,
      }),
    });
    if (!response.ok) throw new Error('Recovery delivery failed');
  }
}
