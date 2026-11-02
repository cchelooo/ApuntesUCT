// @vitest-environment jsdom

import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { RegisterPage } from './RegisterPage';

function renderPage() {
  render(
    <MemoryRouter>
      <RegisterPage />
    </MemoryRouter>
  );
}

describe('RegisterPage', () => {
  it('muestra errores claros para los campos obligatorios', () => {
    renderPage();

    fireEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }));

    expect(screen.getByRole('alert')).toHaveTextContent(
      'Revisa los campos indicados antes de continuar.'
    );
    expect(screen.getByText('Ingresa tu nombre completo.')).toBeInTheDocument();
    expect(
      screen.getByText('Ingresa tu correo electrónico.')
    ).toBeInTheDocument();
    expect(screen.getByText('Ingresa una contraseña.')).toBeInTheDocument();
    expect(screen.getByText('Selecciona tu carrera.')).toBeInTheDocument();
    expect(screen.getByLabelText('Nombre completo')).toHaveAttribute(
      'aria-invalid',
      'true'
    );
  });

  it('valida correo, contraseña y anuncia cuando los campos están completos', () => {
    renderPage();

    fireEvent.change(screen.getByLabelText('Nombre completo'), {
      target: { value: 'Valentina Torres' },
    });
    fireEvent.change(screen.getByLabelText('Correo electrónico'), {
      target: { value: 'correo-invalido' },
    });
    fireEvent.change(screen.getByLabelText('Contraseña'), {
      target: { value: '123' },
    });
    fireEvent.change(screen.getByLabelText('Carrera'), {
      target: { value: '1' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }));

    expect(
      screen.getByText('Ingresa un correo electrónico válido.')
    ).toBeInTheDocument();
    expect(
      screen.getByText('La contraseña debe tener al menos 8 caracteres.')
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Correo electrónico'), {
      target: { value: 'valentina@uct.cl' },
    });
    fireEvent.change(screen.getByLabelText('Contraseña'), {
      target: { value: 'clave-segura-123' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Crear cuenta' }));

    expect(screen.getByRole('status')).toHaveTextContent(
      'Los datos son válidos, pero el registro de cuentas aún no está habilitado.'
    );
  });
});
