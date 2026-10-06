import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import type { MaterialViewStatus } from '../../domain/material/material';
import { MaterialDetailPage } from './MaterialDetailPage';

function renderAt(path: string, status?: MaterialViewStatus) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route
          path="/material/:materialId"
          element={<MaterialDetailPage status={status} />}
        />
        <Route path="/catalog" element={<p>Catálogo</p>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('MaterialDetailPage', () => {
  it('lee el materialId desde la ruta', () => {
    renderAt('/material/abc-123');
    expect(screen.getByTestId('material-id')).toHaveTextContent('abc-123');
  });

  it('muestra espacio para metadatos y versión actual', () => {
    renderAt('/material/abc-123');
    expect(screen.getByText('Datos del material')).toBeInTheDocument();
    expect(screen.getByText('Versión actual')).toBeInTheDocument();
  });

  it('incluye la acción visual de descarga', () => {
    renderAt('/material/abc-123');
    expect(
      screen.getByRole('button', { name: /descargar material/i })
    ).toBeInTheDocument();
  });

  it.each(['unavailable', 'not-found'] as const)(
    'representa el estado %s con una salida de navegación',
    (status) => {
      renderAt('/material/abc-123', status);
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(
        screen.getByRole('link', { name: /volver al catálogo/i })
      ).toHaveAttribute('href', '/catalog');
      expect(
        screen.queryByRole('button', { name: /descargar material/i })
      ).not.toBeInTheDocument();
    }
  );
});
