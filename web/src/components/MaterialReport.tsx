import {
  useEffect,
  useId,
  useRef,
  useState,
  type FormEvent,
  type KeyboardEvent,
} from 'react';
import type {
  QualityInteractionsAdapter,
  ReportReason,
} from '../domain/quality/qualityInteractions';
import {
  getOperationFeedback,
  hasValidAccessToken,
  REPORT_REASONS,
} from '../domain/quality/qualityInteractions';
import { localQualityAdapter } from '../adapters/localQualityAdapter';

export interface MaterialReportProps {
  materialId: string;
  accessToken?: string;
  adapter?: QualityInteractionsAdapter;
}

export function MaterialReport({ accessToken, ...props }: MaterialReportProps) {
  return (
    <MaterialReportForSession
      key={accessToken ?? ''}
      accessToken={accessToken}
      {...props}
    />
  );
}

function MaterialReportForSession({
  materialId,
  accessToken,
  adapter = localQualityAdapter,
}: MaterialReportProps) {
  const id = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const reasonRef = useRef<HTMLSelectElement>(null);
  const confirmationRef = useRef<HTMLButtonElement>(null);
  const [isOpen, setIsOpen] = useState(false);
  const [reason, setReason] = useState<ReportReason | ''>('');
  const [details, setDetails] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [feedback, setFeedback] = useState('');
  const [error, setError] = useState('');
  const isAuthenticated = hasValidAccessToken(accessToken);
  const operationIdRef = useRef(0);

  useEffect(
    () => () => {
      operationIdRef.current += 1;
    },
    []
  );

  useEffect(() => {
    if (!isOpen) return;

    const previouslyFocused = document.activeElement;
    reasonRef.current?.focus();
    return () => {
      if (previouslyFocused instanceof HTMLElement) {
        previouslyFocused.focus();
      }
    };
  }, [isOpen]);

  useEffect(() => {
    if (isSubmitted) confirmationRef.current?.focus();
  }, [isSubmitted]);

  function closeDialog() {
    if (isSubmitting) return;
    setIsOpen(false);
    setReason('');
    setDetails('');
    setError('');
    setIsSubmitted(false);
  }

  function handleDialogKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeDialog();
      return;
    }
    if (event.key !== 'Tab') return;

    const dialog = dialogRef.current;
    if (!dialog) return;
    const focusable = Array.from(
      dialog.querySelectorAll<HTMLElement>(
        'button:not(:disabled), select:not(:disabled), textarea:not(:disabled)'
      )
    );
    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last?.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first?.focus();
    }
  }

  async function submitReport(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!hasValidAccessToken(accessToken) || !reason || isSubmitting) return;

    const operationId = ++operationIdRef.current;
    setIsSubmitting(true);
    setError('');
    setFeedback('');

    try {
      const receipt = await adapter.submitReport({
        materialId,
        reason,
        details: details.trim() || undefined,
        accessToken,
      });
      if (operationId !== operationIdRef.current) return;
      setFeedback(
        getOperationFeedback(
          receipt,
          'Reporte confirmado en la demostración local; no fue enviado al equipo.',
          'El reporte fue enviado correctamente.'
        )
      );
      setIsSubmitted(true);
    } catch {
      if (operationId !== operationIdRef.current) return;
      setError('No se pudo enviar el reporte. Inténtalo nuevamente más tarde.');
    } finally {
      if (operationId === operationIdRef.current) setIsSubmitting(false);
    }
  }

  return (
    <div className="flex flex-col items-start gap-2">
      <button
        type="button"
        disabled={!isAuthenticated}
        aria-describedby={`${id}-auth`}
        onClick={() => {
          setFeedback('');
          setError('');
          setIsSubmitted(false);
          setIsOpen(true);
        }}
        className="min-h-11 rounded-xs px-3 py-2 text-sm font-medium text-catalog-primary underline decoration-transparent underline-offset-4 hover:decoration-current focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-catalog-primary disabled:cursor-not-allowed disabled:opacity-60"
      >
        Reportar problema
      </button>
      <p id={`${id}-auth`} className="text-xs text-catalog-ink/70">
        {!isAuthenticated
          ? 'Inicia sesión para reportar este material.'
          : 'Demostración local: no se sincroniza con el servidor.'}
      </p>
      {feedback && !isOpen && (
        <p role="status" className="text-sm text-catalog-ink">
          {feedback}
        </p>
      )}

      {isOpen && isAuthenticated && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-black/50 p-4">
          <div
            ref={dialogRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={`${id}-title`}
            aria-describedby={`${id}-description`}
            onKeyDown={handleDialogKeyDown}
            className="w-full max-w-lg rounded-xs border border-catalog-line bg-catalog-paper p-6 text-catalog-ink shadow-xl"
          >
            <h2 id={`${id}-title`} className="font-display text-2xl">
              Reportar material
            </h2>
            <p
              id={`${id}-description`}
              className="mt-2 text-sm text-catalog-ink/70"
            >
              Cuéntanos qué problema encontraste. El reporte de esta versión es
              una demostración local.
            </p>

            {isSubmitted ? (
              <div className="mt-5">
                <p role="status" className="text-sm text-green-800">
                  {feedback}
                </p>
                <button
                  type="button"
                  ref={confirmationRef}
                  onClick={closeDialog}
                  className="mt-5 min-h-11 rounded-xs bg-uct-blue px-4 py-2 font-medium text-white hover:bg-uct-blueDark focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-catalog-primary"
                >
                  Cerrar
                </button>
              </div>
            ) : (
              <form className="mt-5 space-y-4" onSubmit={submitReport}>
                <div>
                  <label
                    htmlFor={`${id}-reason`}
                    className="mb-1 block text-sm font-medium"
                  >
                    Motivo del reporte
                  </label>
                  <select
                    ref={reasonRef}
                    id={`${id}-reason`}
                    required
                    value={reason}
                    onChange={(event) =>
                      setReason(event.target.value as ReportReason | '')
                    }
                    className="min-h-11 w-full rounded-xs border border-catalog-line bg-white px-3 py-2 focus-visible:outline-2 focus-visible:outline-catalog-primary"
                  >
                    <option value="" disabled>
                      Selecciona un motivo
                    </option>
                    {REPORT_REASONS.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label
                    htmlFor={`${id}-details`}
                    className="mb-1 block text-sm font-medium"
                  >
                    Detalles (opcional)
                  </label>
                  <textarea
                    id={`${id}-details`}
                    value={details}
                    maxLength={500}
                    rows={4}
                    onChange={(event) => setDetails(event.target.value)}
                    className="w-full resize-y rounded-xs border border-catalog-line bg-white px-3 py-2 focus-visible:outline-2 focus-visible:outline-catalog-primary"
                  />
                  <p className="mt-1 text-right text-xs text-catalog-ink/60">
                    {details.length}/500
                  </p>
                </div>
                {error && (
                  <p role="alert" className="text-sm text-red-700">
                    {error}
                  </p>
                )}
                <div className="flex flex-wrap justify-end gap-3">
                  <button
                    type="button"
                    disabled={isSubmitting}
                    onClick={closeDialog}
                    className="min-h-11 rounded-xs border border-catalog-line px-4 py-2 font-medium hover:bg-catalog-paperMuted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-catalog-primary disabled:opacity-60"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmitting || !accessToken}
                    aria-busy={isSubmitting}
                    className="min-h-11 rounded-xs bg-uct-blue px-4 py-2 font-medium text-white hover:bg-uct-blueDark focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-catalog-primary disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {isSubmitting ? 'Enviando…' : 'Enviar reporte'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
