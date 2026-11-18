import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type {
  QualityInteractionsAdapter,
  QualityOperationReceipt,
} from '../../../domain/quality/qualityInteractions';
import { RatingSelector } from './RatingSelector';

function createAdapter(
  submitRating: QualityInteractionsAdapter['submitRating']
): QualityInteractionsAdapter {
  return {
    setFavorite: vi.fn(),
    submitRating,
    submitReport: vi.fn(),
  };
}

describe('RatingSelector', () => {
  it('requiere sesión para calificar un material', () => {
    render(<RatingSelector materialId="material-1" />);

    expect(screen.getByRole('radiogroup')).toBeInTheDocument();
    expect(screen.getByRole('radio', { name: '1 estrella' })).toBeDisabled();
    expect(
      screen.getByText('Inicia sesión para calificar este material.')
    ).toBeInTheDocument();
  });

  it.each(['', '   '])('rechaza el token %j', async (accessToken) => {
    const user = userEvent.setup();
    const submitRating = vi.fn();

    render(
      <RatingSelector
        materialId="material-1"
        accessToken={accessToken}
        adapter={createAdapter(submitRating)}
      />
    );

    const firstStar = screen.getByRole('radio', { name: '1 estrella' });
    expect(firstStar).toBeDisabled();
    await user.click(firstStar);
    expect(submitRating).not.toHaveBeenCalled();
  });

  it('permite elegir estrellas con el teclado', async () => {
    const user = userEvent.setup();
    const submitRating = vi.fn(async () => ({ source: 'local-demo' as const }));

    render(
      <RatingSelector
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitRating)}
      />
    );

    const firstStar = screen.getByRole('radio', { name: '1 estrella' });
    await user.click(firstStar);
    expect(firstStar).toBeChecked();
    expect(
      await screen.findByText(
        'Calificación actualizada localmente; no se envió al servidor.'
      )
    ).toBeInTheDocument();

    await user.keyboard('{ArrowRight}');
    expect(screen.getByRole('radio', { name: '2 estrellas' })).toBeChecked();
    expect(submitRating).toHaveBeenLastCalledWith({
      materialId: 'material-1',
      rating: 2,
      accessToken: 'session-token',
    });
  });

  it('muestra la selección de inmediato y espera la respuesta del adaptador', async () => {
    const user = userEvent.setup();
    let resolveOperation!: (receipt: QualityOperationReceipt) => void;
    const pendingOperation = new Promise<QualityOperationReceipt>((resolve) => {
      resolveOperation = resolve;
    });
    const submitRating = vi.fn(() => pendingOperation);

    render(
      <RatingSelector
        materialId="material-1"
        accessToken="session-token"
        adapter={createAdapter(submitRating)}
      />
    );

    const fourthStar = screen.getByRole('radio', { name: '4 estrellas' });
    await user.click(fourthStar);
    expect(fourthStar).toBeChecked();
    expect(screen.getByText('Guardando calificación…')).toBeInTheDocument();

    resolveOperation({ source: 'local-demo' });
    expect(
      await screen.findByText(
        'Calificación actualizada localmente; no se envió al servidor.'
      )
    ).toBeInTheDocument();
  });

  it('revierte la selección y no anuncia éxito cuando falla', async () => {
    const user = userEvent.setup();
    const submitRating = vi.fn().mockRejectedValue(new Error('fallo de red'));

    render(
      <RatingSelector
        materialId="material-1"
        accessToken="session-token"
        initialRating={2}
        adapter={createAdapter(submitRating)}
      />
    );

    await user.click(screen.getByRole('radio', { name: '5 estrellas' }));
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'No se pudo guardar la calificación.'
    );
    expect(screen.getByRole('radio', { name: '2 estrellas' })).toBeChecked();
    expect(
      screen.queryByText(/Calificación actualizada localmente/)
    ).not.toBeInTheDocument();
  });

  it('ignora una respuesta tardía después de perder la sesión', async () => {
    const user = userEvent.setup();
    let resolveOperation!: (receipt: QualityOperationReceipt) => void;
    const submitRating = vi.fn(
      () =>
        new Promise<QualityOperationReceipt>((resolve) => {
          resolveOperation = resolve;
        })
    );
    const adapter = createAdapter(submitRating);
    const { rerender } = render(
      <RatingSelector
        materialId="material-1"
        accessToken="session-token"
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('radio', { name: '4 estrellas' }));
    rerender(<RatingSelector materialId="material-1" adapter={adapter} />);
    resolveOperation({ source: 'local-demo' });

    expect(
      await screen.findByText('Inicia sesión para calificar este material.')
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/Calificación actualizada localmente/)
    ).not.toBeInTheDocument();
  });
});
