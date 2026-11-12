import { AuthController } from './auth.controller';
import { LoginService } from '../../application/auth/login.service';

describe('AuthController', () => {
  it('delega las credenciales al caso de uso', async () => {
    const login = jest.fn().mockResolvedValue({ accessToken: 'signed' });
    const controller = new AuthController({ login } as unknown as LoginService);
    const input = { email: 'user@uct.cl', password: ' exacta ' };
    expect(await controller.login(input)).toEqual({ accessToken: 'signed' });
    expect(login).toHaveBeenCalledWith(input);
  });
});
