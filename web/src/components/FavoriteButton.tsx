import { useId, useState } from 'react';
import type { QualityInteractionsAdapter } from '../domain/quality/qualityInteractions';
import { getOperationFeedback } from '../domain/quality/qualityInteractions';
import { localQualityAdapter } from '../adapters/localQualityAdapter';

export interface FavoriteButtonProps {
  materialId: string;
  accessToken?: string;
  initialFavorite?: boolean;
  adapter?: QualityInteractionsAdapter;
}

export function FavoriteButton({
  materialId,
  accessToken,
  initialFavorite = false,
  adapter = localQualityAdapter,
}: FavoriteButtonProps) {
  const messageId = useId();
  const [isFavorite, setIsFavorite] = useState(initialFavorite);
  const [isSaving, setIsSaving] = useState(false);
  const [feedback, setFeedback] = useState('');
  const [error, setError] = useState('');
  const isAuthenticated = Boolean(accessToken?.trim());

  async function toggleFavorite() {
    if (!accessToken || isSaving) return;

    const nextFavorite = !isFavorite;
    setIsSaving(true);
    setFeedback('');
    setError('');

    try {
      const receipt = await adapter.setFavorite({
        materialId,
        isFavorite: nextFavorite,
        accessToken,
      });
      setIsFavorite(nextFavorite);
      setFeedback(
        getOperationFeedback(
          receipt,
          nextFavorite
            ? 'Favorito actualizado localmente; no se envió al servidor.'
            : 'Favorito quitado localmente; no se envió al servidor.',
          nextFavorite
            ? 'Material agregado a favoritos.'
            : 'Material quitado de favoritos.'
        )
      );
    } catch {
      setError(
        'No se pudo actualizar favoritos. Inténtalo nuevamente más tarde.'
      );
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <div className="flex flex-col items-start gap-1">
      <button
        type="button"
        aria-pressed={isFavorite}
        aria-describedby={messageId}
        aria-busy={isSaving}
        disabled={!isAuthenticated || isSaving}
        onClick={toggleFavorite}
        className="inline-flex min-h-11 items-center gap-2 rounded-xs border border-catalog-line bg-catalog-paper px-3 py-2 text-sm font-medium text-catalog-ink hover:bg-catalog-paperMuted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-catalog-primary disabled:cursor-not-allowed disabled:opacity-60"
      >
        <svg
          aria-hidden="true"
          viewBox="0 0 24 24"
          className="h-5 w-5"
          fill={isFavorite ? 'currentColor' : 'none'}
          stroke="currentColor"
          strokeWidth="1.8"
        >
          <path d="M6 4.75A1.75 1.75 0 0 1 7.75 3h8.5A1.75 1.75 0 0 1 18 4.75V21l-6-4-6 4V4.75Z" />
        </svg>
        <span>
          {isSaving
            ? 'Guardando…'
            : isFavorite
              ? 'Quitar de favoritos'
              : 'Agregar a favoritos'}
        </span>
      </button>
      <p
        id={messageId}
        className="text-xs text-catalog-ink/70"
        aria-live="polite"
      >
        {!isAuthenticated
          ? 'Inicia sesión para guardar favoritos.'
          : isSaving
            ? 'Actualizando favoritos…'
            : feedback ||
              'Demostración local: no se sincroniza con el servidor.'}
      </p>
      {error && (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      )}
    </div>
  );
}
