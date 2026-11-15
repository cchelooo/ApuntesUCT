import { useId, useState } from 'react';
import type {
  QualityInteractionsAdapter,
  RatingValue,
} from '../domain/quality/qualityInteractions';
import { getOperationFeedback } from '../domain/quality/qualityInteractions';
import { localQualityAdapter } from '../adapters/localQualityAdapter';

export interface RatingSelectorProps {
  materialId: string;
  accessToken?: string;
  initialRating?: RatingValue;
  adapter?: QualityInteractionsAdapter;
}

export function RatingSelector({
  materialId,
  accessToken,
  initialRating,
  adapter = localQualityAdapter,
}: RatingSelectorProps) {
  const groupName = useId();
  const [rating, setRating] = useState<RatingValue | undefined>(initialRating);
  const [isSaving, setIsSaving] = useState(false);
  const [feedback, setFeedback] = useState('');
  const [error, setError] = useState('');
  const isAuthenticated = Boolean(accessToken?.trim());

  async function selectRating(nextRating: RatingValue) {
    if (!accessToken || isSaving) return;

    const previousRating = rating;
    setRating(nextRating);
    setIsSaving(true);
    setFeedback('');
    setError('');

    try {
      const receipt = await adapter.submitRating({
        materialId,
        rating: nextRating,
        accessToken,
      });
      setFeedback(
        getOperationFeedback(
          receipt,
          'Calificación actualizada localmente; no se envió al servidor.',
          'Tu calificación fue registrada.'
        )
      );
    } catch {
      setRating(previousRating);
      setError(
        'No se pudo guardar la calificación. Inténtalo nuevamente más tarde.'
      );
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <fieldset
      disabled={!isAuthenticated || isSaving}
      aria-busy={isSaving}
      className="min-w-0"
    >
      <legend className="font-medium text-catalog-ink">
        Califica este material
      </legend>
      <div
        role="radiogroup"
        aria-label="Calificación de 1 a 5 estrellas"
        className="mt-2 flex items-center gap-1"
      >
        {([1, 2, 3, 4, 5] as const).map((value) => (
          <label
            key={value}
            className="group relative inline-flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-xs text-3xl text-amber-500 focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-catalog-primary has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-60"
          >
            <input
              className="peer sr-only"
              type="radio"
              name={groupName}
              value={value}
              checked={rating === value}
              aria-label={`${value} ${value === 1 ? 'estrella' : 'estrellas'}`}
              onChange={() => void selectRating(value)}
            />
            <span aria-hidden="true" className="peer-checked:scale-110">
              {rating !== undefined && value <= rating ? '★' : '☆'}
            </span>
          </label>
        ))}
        {rating !== undefined && (
          <span className="ml-2 text-sm text-catalog-ink" aria-hidden="true">
            {rating}/5
          </span>
        )}
      </div>
      <p
        aria-live="polite"
        className="mt-1 min-h-5 text-sm text-catalog-ink/70"
      >
        {!isAuthenticated
          ? 'Inicia sesión para calificar este material.'
          : isSaving
            ? 'Guardando calificación…'
            : feedback ||
              'Demostración local: no se sincroniza con el servidor.'}
      </p>
      {error && (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      )}
    </fieldset>
  );
}
