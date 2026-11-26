import { useState } from 'react';
import type {
  AdministrativeRole,
  ModerationAdapter,
  ModerationAction,
} from '../../../domain/moderation/moderation';
import { canModerate } from '../../../domain/moderation/moderation';
import { Alert } from '../Alert';
import { Button } from '../Button';

interface ModerationPanelProps {
  materialId: string;
  accessToken?: string;
  role?: AdministrativeRole | string;
  expectedRevision: number;
  adapter: ModerationAdapter;
  idempotencyKey?: string;
}

export function ModerationPanel({
  materialId,
  accessToken,
  role,
  expectedRevision,
  adapter,
  idempotencyKey = 'moderation-test-operation',
}: ModerationPanelProps) {
  const [reason, setReason] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const authorized =
    canModerate(role) &&
    typeof accessToken === 'string' &&
    accessToken.trim().length > 0;

  const submit = async (action: ModerationAction) => {
    if (!authorized) return;
    setError(null);
    setSuccess(null);

    if (action === 'REJECT' && !reason.trim()) {
      setError('Indica el motivo obligatorio para rechazar el material.');
      return;
    }

    setIsSubmitting(true);
    try {
      const receipt = await adapter.submitDecision({
        materialId,
        action,
        reason: action === 'REJECT' ? reason.trim() : undefined,
        expectedRevision,
        accessToken,
        role,
        idempotencyKey,
      });

      if (receipt.state === 'FAILED') {
        setError('La decisión fue rechazada definitivamente por el sistema.');
      } else if (receipt.state === 'PENDING_APPLICATION') {
        setSuccess(
          'Decisión enviada; el material seguirá pendiente hasta que se confirme su aplicación.'
        );
      } else {
        setSuccess(
          action === 'APPROVE' ? 'Material aprobado.' : 'Material rechazado.'
        );
      }
    } catch (caught) {
      const status =
        typeof caught === 'object' &&
        caught !== null &&
        'status' in caught &&
        typeof caught.status === 'number'
          ? caught.status
          : undefined;
      setError(
        status === 403
          ? 'No tienes permisos administrativos para realizar esta acción.'
          : caught instanceof Error
            ? caught.message
            : 'No se pudo procesar la decisión de moderación.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section aria-label="Moderación de materiales">
      {!authorized && (
        <Alert
          variant="error"
          message="Solo usuarios MODERATOR o ADMIN pueden moderar materiales."
        />
      )}
      {error && <Alert variant="error" message={error} />}
      {success && <Alert variant="success" message={success} />}

      <label className="mt-4 block text-sm" htmlFor="moderation-reason">
        Motivo del rechazo
      </label>
      <textarea
        id="moderation-reason"
        value={reason}
        onChange={(event) => setReason(event.target.value)}
        disabled={!authorized || isSubmitting}
        className="mt-1 min-h-24 w-full rounded-xs border px-3 py-2"
      />

      <div className="mt-3 flex gap-3">
        <Button
          type="button"
          onClick={() => void submit('APPROVE')}
          disabled={!authorized || isSubmitting}
        >
          {isSubmitting ? 'Procesando...' : 'Aprobar'}
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => void submit('REJECT')}
          disabled={!authorized || isSubmitting}
        >
          Rechazar
        </Button>
      </div>
    </section>
  );
}
