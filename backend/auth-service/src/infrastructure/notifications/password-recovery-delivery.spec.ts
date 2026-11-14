import { ConfigService } from '@nestjs/config';
import { PasswordRecoveryDelivery } from './password-recovery-delivery';

describe('PasswordRecoveryDelivery', () => {
  const fetchMock = jest.fn();
  const originalFetch = global.fetch;
  beforeEach(() => {
    global.fetch = fetchMock;
    fetchMock.mockReset();
  });
  afterEach(() => {
    global.fetch = originalFetch;
  });
  const delivery = (url?: string, secret?: string) =>
    new PasswordRecoveryDelivery(
      new ConfigService({
        PASSWORD_RECOVERY_DELIVERY_URL: url,
        PASSWORD_RECOVERY_DELIVERY_SECRET: secret,
      }),
    );

  it.each([
    [undefined, undefined],
    ['http://mail.example', 'secret'],
    ['https://mail.example', undefined],
    ['https://user:pass@mail.example', 'secret'],
  ])('rechaza configuración insegura o ausente', async (url, secret) => {
    await expect(
      delivery(url, secret).send('user@uct.cl', 'token', new Date()),
    ).rejects.toThrow();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('envía por HTTPS autenticado, sin redirects y con timeout', async () => {
    fetchMock.mockResolvedValue({ ok: true });
    const expiresAt = new Date();
    await delivery('https://mail.example/recovery', 'secret').send(
      'user@uct.cl',
      'token',
      expiresAt,
    );
    expect(fetchMock).toHaveBeenCalledWith(
      new URL('https://mail.example/recovery'),
      {
        method: 'POST',
        redirect: 'error',
        signal: expect.any(AbortSignal) as AbortSignal,
        headers: {
          Authorization: 'Bearer secret',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type: 'password-recovery',
          email: 'user@uct.cl',
          token: 'token',
          expiresAt,
        }),
      },
    );
  });

  it('rechaza respuestas fallidas', async () => {
    fetchMock.mockResolvedValue({ ok: false });
    await expect(
      delivery('https://mail.example', 'secret').send(
        'user@uct.cl',
        'token',
        new Date(),
      ),
    ).rejects.toThrow('Recovery delivery failed');
  });
});
