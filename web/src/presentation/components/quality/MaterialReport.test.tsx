import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { QualityInteractionsAdapter } from '../../../domain/quality/qualityInteractions';
import { MaterialReport } from './MaterialReport';

function createAdapter(
  submitReport: QualityInteractionsAdapter['submitReport']
): QualityInteractionsAdapter {
  return {
    setFavorite: vi.fn(),
    submitRating: vi.fn(),
    submitReport,
  };
}

describe('MaterialReport', () => {
  it('bloquea el formulario de reporte si no hay sesión', async () => {
    const user = userEvent.setup();
    const submitReport = vi.fn();

    render(
      <MaterialReport
        materialId="material-1"
        adapter={createAdapter(submitReport)}
      />
    );

    const trigger = screen.getByRole('button', { name: 'Reportar problema' });
    expect(trigger).toBeDisabled();
    expect(
      screen.getByText('Inicia sesión para reportar este material.')
    ).toBeInTheDocument();
    await user.click(trigger);
    expect(submitReport).not.toHaveBeenCalled();
  });

  it('cierra al cancelar sin anunciar una confirmación exitosa', async () => {
    const user = userEvent.setup();
    const submitReport = vi.fn();

    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitReport)}
      />
    );

    const trigger = screen.getByRole('button', { name: 'Reportar problema' });
    await user.click(trigger);
    await user.selectOptions(
      screen.getByRole('combobox', { name: 'Motivo del reporte' }),
      'broken-link'
    );
    await user.click(screen.getByRole('button', { name: 'Cancelar' }));

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
    expect(submitReport).not.toHaveBeenCalled();
    expect(trigger).toHaveFocus();
  });

  it('muestra confirmación solo tras el envío exitoso y lo identifica como demo', async () => {
    const user = userEvent.setup();
    const submitReport = vi.fn(async () => ({ source: 'local-demo' as const }));

    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitReport)}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Reportar problema' }));
    await user.selectOptions(
      screen.getByRole('combobox', { name: 'Motivo del reporte' }),
      'incorrect-content'
    );
    await user.type(
      screen.getByRole('textbox', { name: 'Detalles (opcional)' }),
      'El año del material no coincide.'
    );
    await user.click(screen.getByRole('button', { name: 'Enviar reporte' }));

    expect(await screen.findByRole('status')).toHaveTextContent(
      'Reporte confirmado en la demostración local; no fue enviado al equipo.'
    );
    expect(submitReport).toHaveBeenCalledWith({
      materialId: 'material-1',
      reason: 'incorrect-content',
      details: 'El año del material no coincide.',
      accessToken: 'session-token',
    });
    expect(screen.getByRole('dialog')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Cerrar' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent(
      'no fue enviado al equipo'
    );
  });

  it('mantiene el formulario abierto y no confirma si el envío falla', async () => {
    const user = userEvent.setup();
    const submitReport = vi.fn().mockRejectedValue(new Error('fallo de red'));

    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitReport)}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Reportar problema' }));
    await user.selectOptions(
      screen.getByRole('combobox', { name: 'Motivo del reporte' }),
      'spam'
    );
    await user.click(screen.getByRole('button', { name: 'Enviar reporte' }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se pudo enviar el reporte.'
    );
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });

  it('cierra con Escape sin enviar y devuelve el foco al control', async () => {
    const user = userEvent.setup();
    const submitReport = vi.fn();

    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitReport)}
      />
    );

    const trigger = screen.getByRole('button', { name: 'Reportar problema' });
    await user.click(trigger);
    await user.keyboard('{Escape}');

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
    expect(submitReport).not.toHaveBeenCalled();
    expect(trigger).toHaveFocus();
  });

  it('mantiene la navegación Tab dentro del diálogo', async () => {
    const user = userEvent.setup();

    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(vi.fn())}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Reportar problema' }));
    const reason = screen.getByRole('combobox', {
      name: 'Motivo del reporte',
    });
    const submit = screen.getByRole('button', { name: 'Enviar reporte' });

    expect(reason).toHaveFocus();
    await user.tab({ shift: true });
    expect(submit).toHaveFocus();
    await user.tab();
    expect(reason).toHaveFocus();
  });
});
