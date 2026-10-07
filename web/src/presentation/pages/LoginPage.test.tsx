// @vitest-environment jsdom

import { render, screen, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { LoginPage } from './LoginPage';

describe('LoginPage', () => {
  afterEach(() => vi.unstubAllGlobals());

  function renderAndSubmit() {
    render(
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <LoginPage />
        </MemoryRouter>
      </QueryClientProvider>
    );
    fireEvent.change(screen.getByLabelText('Correo electrónico'), {
      target: { value: 'qa@alu.uct.cl' },
    });
    fireEvent.change(screen.getByLabelText('Contraseña'), {
      target: { value: 'demo' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ingresar' }));
  }

  it.each([
    [
      400,
      'Los datos ingresados no son válidos. Revisa tu correo y contraseña.',
    ],
    [
      502,
      'El servicio de autenticación no está disponible. Inténtalo nuevamente más tarde.',
    ],
    [500, 'No fue posible iniciar sesión. Inténtalo nuevamente más tarde.'],
  ])(
    'presenta un mensaje comprensible para HTTP %s',
    async (status, message) => {
      vi.stubGlobal(
        'fetch',
        vi.fn().mockResolvedValue(new Response('{}', { status }))
      );
      renderAndSubmit();
      expect(await screen.findByRole('alert')).toHaveTextContent(message);
      expect(screen.getByRole('button', { name: 'Ingresar' })).toBeEnabled();
    }
  );

  it('muestra el fallo de red y permite reintentar', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new TypeError('Failed to fetch'))
    );
    renderAndSubmit();
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se pudo conectar con el servidor.'
    );
    expect(screen.getByRole('button', { name: 'Ingresar' })).toBeEnabled();
  });

  it('impide el doble envío mientras espera y muestra el éxito', async () => {
    let resolveResponse!: (response: Response) => void;
    const fetchMock = vi.fn().mockImplementation(
      () =>
        new Promise<Response>((resolve) => {
          resolveResponse = resolve;
        })
    );
    vi.stubGlobal('fetch', fetchMock);
    renderAndSubmit();
    const pendingButton = await screen.findByRole('button', {
      name: 'Ingresando...',
    });
    expect(pendingButton).toBeDisabled();
    fireEvent.click(pendingButton);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe(
      `${import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'}/auth/login`
    );
    expect(JSON.parse(options.body)).toEqual({
      email: 'qa@alu.uct.cl',
      password: 'demo',
    });
    resolveResponse(new Response('{}', { status: 200 }));
    expect(await screen.findByRole('status')).toHaveTextContent(
      'Inicio de sesión exitoso.'
    );
  });

  it('renders the main login elements', () => {
    const queryClient = new QueryClient();

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <LoginPage />
        </MemoryRouter>
      </QueryClientProvider>
    );

    expect(screen.getByRole('heading', { name: 'Ingresar' })).toBeTruthy();
    expect(screen.getByLabelText('Correo electrónico')).toBeTruthy();
    expect(screen.getByLabelText('Contraseña')).toBeTruthy();
    expect(
      screen.getByRole('button', { name: 'Continuar con Google' })
    ).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Ingresar' })).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Registrarse' })).toBeTruthy();
  });
});
