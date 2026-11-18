import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { QualityInteractionsAdapter } from '../../adapters/localQualityAdapter';
import { FavoriteButton } from '../FavoriteButton';
import { MaterialReport } from '../MaterialReport';
import { RatingSelector } from '../RatingSelector';

function createAdapter(
  overrides: Partial<QualityInteractionsAdapter> = {}
): QualityInteractionsAdapter {
  return {
    setFavorite: vi.fn(async () => ({ source: 'local-demo' as const })),
    submitRating: vi.fn(async () => ({ source: 'local-demo' as const })),
    submitReport: vi.fn(async () => ({ source: 'local-demo' as const })),
    ...overrides,
  };
}

describe('componentes Quality en web/src/components', () => {
  it('exporta el control de favoritos y requiere sesión', async () => {
    const user = userEvent.setup();
    const adapter = createAdapter();
    render(<FavoriteButton materialId="material-1" adapter={adapter} />);

    const button = screen.getByRole('button', { name: 'Agregar a favoritos' });
    expect(button).toBeDisabled();
    expect(
      screen.getByText('Inicia sesión para guardar favoritos.')
    ).toBeInTheDocument();

    await user.click(button);
    expect(adapter.setFavorite).not.toHaveBeenCalled();
  });

  it('exporta el selector accesible y permite navegar por teclado', async () => {
    const user = userEvent.setup();
    const adapter = createAdapter();
    render(
      <RatingSelector
        materialId="material-1"
        accessToken="session"
        adapter={adapter}
      />
    );

    const firstStar = screen.getByRole('radio', { name: '1 estrella' });
    await user.click(firstStar);
    await user.keyboard('{ArrowRight}');

    expect(screen.getByRole('radio', { name: '2 estrellas' })).toBeChecked();
    expect(adapter.submitRating).toHaveBeenCalledWith({
      materialId: 'material-1',
      rating: 2,
      accessToken: 'session',
    });
  });

  it('exporta el formulario de reporte y cancelar no confirma ni envía', async () => {
    const user = userEvent.setup();
    const adapter = createAdapter();
    render(
      <MaterialReport
        materialId="material-1"
        accessToken="session"
        adapter={adapter}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Reportar problema' }));
    await user.selectOptions(
      screen.getByRole('combobox', { name: 'Motivo del reporte' }),
      'broken-link'
    );
    await user.click(screen.getByRole('button', { name: 'Cancelar' }));

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
    expect(adapter.submitReport).not.toHaveBeenCalled();
  });
});
