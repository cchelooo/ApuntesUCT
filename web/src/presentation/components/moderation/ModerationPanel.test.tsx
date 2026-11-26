import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { ModerationAdapter } from '../../../domain/moderation/moderation';
import { ModerationPanel } from './ModerationPanel';

function createAdapter(
  result: Parameters<ModerationAdapter['submitDecision']>[0] | null = null
) {
  return {
    submitDecision: vi.fn(async () => ({
      httpStatus: 202,
      state: 'PENDING_APPLICATION' as const,
      operationId: 'operation-1',
      result: result,
      failure: null,
    })),
  };
}

describe('ModerationPanel', () => {
  it('bloquea las acciones para usuarios sin rol administrativo', async () => {
    const user = userEvent.setup();
    const adapter = createAdapter();

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="STUDENT"
        expectedRevision={4}
        adapter={adapter}
      />
    );

    expect(
      screen.getByText(
        'Solo usuarios MODERATOR o ADMIN pueden moderar materiales.'
      )
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Aprobar' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Rechazar' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Aprobar' }));
    expect(adapter.submitDecision).not.toHaveBeenCalled();
  });

  it('aprueba y muestra que la operación quedó pendiente de aplicación', async () => {
    const user = userEvent.setup();
    const adapter = createAdapter();

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="MODERATOR"
        expectedRevision={4}
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Aprobar' }));

    expect(await screen.findByText(/seguirá pendiente/i)).toBeInTheDocument();
    expect(adapter.submitDecision).toHaveBeenCalledWith(
      expect.objectContaining({
        materialId: 'material-1',
        action: 'APPROVE',
        expectedRevision: 4,
      })
    );
  });

  it('rechaza con motivo obligatorio y confirma una respuesta aplicada', async () => {
    const user = userEvent.setup();
    const adapter: ModerationAdapter = {
      submitDecision: vi.fn(async () => ({
        httpStatus: 200,
        state: 'APPLIED' as const,
        operationId: 'operation-2',
        result: { status: 'REJECTED' },
        failure: null,
      })),
    };

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="ADMIN"
        expectedRevision={7}
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Rechazar' }));
    expect(
      await screen.findByText(
        'Indica el motivo obligatorio para rechazar el material.'
      )
    ).toBeInTheDocument();

    await user.type(
      screen.getByRole('textbox', { name: 'Motivo del rechazo' }),
      'Contenido incorrecto'
    );
    await user.click(screen.getByRole('button', { name: 'Rechazar' }));

    expect(await screen.findByText('Material rechazado.')).toBeInTheDocument();
    expect(adapter.submitDecision).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'REJECT',
        reason: 'Contenido incorrecto',
        expectedRevision: 7,
      })
    );
  });

  it('muestra el estado de carga y deshabilita ambas acciones', async () => {
    const user = userEvent.setup();
    let resolveDecision!: (receipt: {
      httpStatus: number;
      state: 'APPLIED';
      operationId: string;
      result: null;
      failure: null;
    }) => void;
    const adapter: ModerationAdapter = {
      submitDecision: vi.fn(
        () =>
          new Promise<{
            httpStatus: number;
            state: 'APPLIED';
            operationId: string;
            result: null;
            failure: null;
          }>((resolve) => {
            resolveDecision = resolve;
          })
      ),
    };

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="MODERATOR"
        expectedRevision={2}
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Aprobar' }));
    expect(
      screen.getByRole('button', { name: 'Procesando...' })
    ).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Rechazar' })).toBeDisabled();

    resolveDecision({
      httpStatus: 200,
      state: 'APPLIED',
      operationId: 'operation-3',
      result: null,
      failure: null,
    });
  });

  it('nunca anuncia éxito ante HTTP 403', async () => {
    const user = userEvent.setup();
    const adapter: ModerationAdapter = {
      submitDecision: vi.fn(async () => {
        throw Object.assign(new Error('Respuesta prohibida'), { status: 403 });
      }),
    };

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="MODERATOR"
        expectedRevision={4}
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Aprobar' }));

    expect(
      await screen.findByText(
        'No tienes permisos administrativos para realizar esta acción.'
      )
    ).toBeInTheDocument();
    expect(screen.queryByText('Material aprobado.')).not.toBeInTheDocument();
  });

  it('muestra un error para una operación fallida', async () => {
    const user = userEvent.setup();
    const adapter: ModerationAdapter = {
      submitDecision: vi.fn(async () => ({
        httpStatus: 200,
        state: 'FAILED' as const,
        operationId: 'operation-4',
        result: null,
        failure: { code: 'STALE_REVISION' },
      })),
    };

    render(
      <ModerationPanel
        materialId="material-1"
        accessToken="session-token"
        role="ADMIN"
        expectedRevision={4}
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Aprobar' }));
    expect(
      await screen.findByText(
        'La decisión fue rechazada definitivamente por el sistema.'
      )
    ).toBeInTheDocument();
  });
});
