import { getApiBaseUrl } from '../apiBaseUrl';

export type ReportReasonContract =
  | 'INAPPROPRIATE_CONTENT'
  | 'COPYRIGHT'
  | 'INCORRECT_INFORMATION'
  | 'BROKEN_RESOURCE'
  | 'OTHER';

export interface CreateReportInput {
  materialId: string;
  reason: ReportReasonContract;
  details?: string;
  accessToken: string;
  idempotencyKey: string;
}

export interface CreateReportReceipt {
  httpStatus: number;
  reportId: string;
  status: string;
}

export class ReportRequestError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'ReportRequestError';
    this.status = status;
  }
}

export async function createMaterialReport(
  input: CreateReportInput
): Promise<CreateReportReceipt> {
  if (!input.accessToken.trim()) {
    throw new ReportRequestError(401, 'Se requiere una sesión autenticada.');
  }
  if (input.reason === 'OTHER' && !input.details?.trim()) {
    throw new ReportRequestError(
      400,
      'El motivo OTHER requiere una explicación.'
    );
  }

  const response = await fetch(
    `${getApiBaseUrl()}/quality/materials/${encodeURIComponent(input.materialId)}/reports`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${input.accessToken}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': input.idempotencyKey,
      },
      body: JSON.stringify({
        reason: input.reason,
        ...(input.details ? { details: input.details } : {}),
      }),
    }
  );

  if (!response.ok) {
    throw new ReportRequestError(
      response.status,
      `No fue posible crear el reporte (HTTP ${response.status}).`
    );
  }

  const body = (await response.json()) as {
    id?: unknown;
    status?: unknown;
  };
  if (typeof body.id !== 'string') {
    throw new ReportRequestError(
      502,
      'La respuesta del reporte no tiene el formato esperado.'
    );
  }

  return {
    httpStatus: response.status,
    reportId: body.id,
    status: typeof body.status === 'string' ? body.status : 'OPEN',
  };
}
