import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type {
  QualityInteractionsAdapter,
  QualityOperationReceipt,
} from '../../../domain/quality/qualityInteractions';
import { FavoriteButton } from './FavoriteButton';

function createAdapter(
  setFavorite: QualityInteractionsAdapter['setFavorite']
): QualityInteractionsAdapter {
  return {
    setFavorite,
    submitRating: vi.fn(),
    submitReport: vi.fn(),
  };
}

describe('FavoriteButton', () => {
  it('requiere una sesión autenticada antes de permitir cambios', async () => {
    const user = userEvent.setup();
    const setFavorite = vi.fn();

    render(
      <FavoriteButton
        materialId="material-1"
        adapter={createAdapter(setFavorite)}
      />
    );

    const button = screen.getByRole('button', {
      name: 'Agregar a favoritos',
    });
    expect(button).toBeDisabled();
    expect(
      screen.getByText('Inicia sesión para guardar favoritos.')
    ).toBeInTheDocument();

    await user.click(button);
    expect(setFavorite).not.toHaveBeenCalled();
  });

  it('actualiza el estado solo después de completar la operación', async () => {
    const user = userEvent.setup();
    let resolveOperation!: (receipt: QualityOperationReceipt) => void;
    const pendingOperation = new Promise<QualityOperationReceipt>((resolve) => {
      resolveOperation = resolve;
    });
    const setFavorite = vi.fn(() => pendingOperation);

    render(
      <FavoriteButton
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(setFavorite)}
      />
    );

    await user.click(
      screen.getByRole('button', { name: 'Agregar a favoritos' })
    );
    expect(setFavorite).toHaveBeenCalledWith({
      materialId: 'material-1',
      isFavorite: true,
      accessToken: 'session-token',
    });
    expect(screen.getByRole('button', { name: 'Guardando…' })).toBeDisabled();
    expect(screen.getByRole('button')).toHaveAttribute('aria-pressed', 'false');

    resolveOperation({ source: 'local-demo' });
    expect(
      await screen.findByRole('button', { name: 'Quitar de favoritos' })
    ).toHaveAttribute('aria-pressed', 'true');
    expect(
      screen.getByText(
        'Favorito actualizado localmente; no se envió al servidor.'
      )
    ).toBeInTheDocument();
  });

  it('conserva el estado y anuncia el error si falla el adaptador', async () => {
    const user = userEvent.setup();
    const setFavorite = vi.fn().mockRejectedValue(new Error('fallo de red'));

    render(
      <FavoriteButton
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(setFavorite)}
      />
    );

    await user.click(
      screen.getByRole('button', { name: 'Agregar a favoritos' })
    );

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se pudo actualizar favoritos.'
    );
    expect(screen.getByRole('button')).toHaveAttribute('aria-pressed', 'false');
    expect(
      screen.queryByText(/Favorito actualizado localmente/)
    ).not.toBeInTheDocument();
  });
});
