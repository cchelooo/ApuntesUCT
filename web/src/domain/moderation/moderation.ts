export type AdministrativeRole = 'MODERATOR' | 'ADMIN';
export type ModerationAction = 'APPROVE' | 'REJECT';
export type ModerationOperationState =
  'PENDING_APPLICATION' | 'APPLIED' | 'FAILED';

export interface ModerationDecision {
  materialId: string;
  action: ModerationAction;
  reason?: string;
  expectedRevision: number;
  accessToken: string;
  role: AdministrativeRole | string;
  idempotencyKey: string;
}

export interface ModerationDecisionReceipt {
  httpStatus: number;
  state: ModerationOperationState;
  operationId: string;
  result: unknown | null;
  failure: unknown | null;
}

export interface ModerationAdapter {
  submitDecision(
    decision: ModerationDecision
  ): Promise<ModerationDecisionReceipt>;
}

export function canModerate(role: unknown): role is AdministrativeRole {
  return role === 'MODERATOR' || role === 'ADMIN';
}
