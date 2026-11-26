import { getApiBaseUrl } from '../apiBaseUrl';
import { canModerate } from '../../domain/moderation/moderation';
import type {
  ModerationDecision,
  ModerationDecisionReceipt,
  ModerationOperationState,
} from '../../domain/moderation/moderation';

export class ModerationRequestError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'ModerationRequestError';
    this.status = status;
  }
}

function isOperationState(value: unknown): value is ModerationOperationState {
  return (
    value === 'PENDING_APPLICATION' || value === 'APPLIED' || value === 'FAILED'
  );
}

export async function submitModerationDecision(
  decision: ModerationDecision
): Promise<ModerationDecisionReceipt> {
  if (!canModerate(decision.role)) {
    throw new ModerationRequestError(
      403,
      'Solo los moderadores y administradores pueden moderar materiales.'
    );
  }

  const response = await fetch(
    `${getApiBaseUrl()}/quality/moderation/materials/${encodeURIComponent(decision.materialId)}/decisions`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${decision.accessToken}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': decision.idempotencyKey,
      },
      body: JSON.stringify({
        action: decision.action,
        expectedRevision: decision.expectedRevision,
        ...(decision.reason ? { reason: decision.reason } : {}),
      }),
    }
  );

  if (!response.ok) {
    throw new ModerationRequestError(
      response.status,
      response.status === 403
        ? 'No tienes permisos administrativos para moderar este material.'
        : `La decisión de moderación falló (HTTP ${response.status}).`
    );
  }

  const body = (await response.json()) as {
    id?: unknown;
    state?: unknown;
    result?: unknown;
    failure?: unknown;
  };

  if (!isOperationState(body.state) || typeof body.id !== 'string') {
    throw new ModerationRequestError(
      502,
      'La respuesta de moderación no tiene el formato esperado.'
    );
  }

  return {
    httpStatus: response.status,
    state: body.state,
    operationId: body.id,
    result: body.result ?? null,
    failure: body.failure ?? null,
  };
}
