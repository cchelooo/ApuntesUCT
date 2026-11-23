import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  ModerationRequestError,
  submitModerationDecision,
} from './moderationApi';

describe('Moderation API contract', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_API_URL', 'https://gateway.test/api/v1');
    window.fetch = vi.fn();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
  });

  it('envía aprobación con Idempotency-Key y interpreta 202 como pendiente', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      status: 202,
      json: () =>
        Promise.resolve({
          id: 'operation-1',
          state: 'PENDING_APPLICATION',
          result: null,
          failure: null,
        }),
    } as unknown as Response);

    const receipt = await submitModerationDecision({
      materialId: 'material-1',
      action: 'APPROVE',
      expectedRevision: 4,
      accessToken: 'session-token',
      role: 'MODERATOR',
      idempotencyKey: 'decision-key',
    });

    expect(receipt.state).toBe('PENDING_APPLICATION');
    expect(receipt.httpStatus).toBe(202);
    const [url, init] = vi.mocked(window.fetch).mock.calls[0];
    expect(url).toBe(
      'https://gateway.test/api/v1/quality/moderation/materials/material-1/decisions'
    );
    expect(init?.method).toBe('POST');
    expect(init?.headers).toEqual(
      expect.objectContaining({
        Authorization: 'Bearer session-token',
        'Idempotency-Key': 'decision-key',
      })
    );
  });

  it('bloquea antes de fetch para roles no administrativos', async () => {
    await expect(
      submitModerationDecision({
        materialId: 'material-1',
        action: 'APPROVE',
        expectedRevision: 4,
        accessToken: 'session-token',
        role: 'STUDENT',
        idempotencyKey: 'decision-key',
      })
    ).rejects.toBeInstanceOf(ModerationRequestError);
    expect(window.fetch).not.toHaveBeenCalled();
  });

  it('propaga 403 sin interpretarlo como éxito', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: false,
      status: 403,
    } as Response);

    await expect(
      submitModerationDecision({
        materialId: 'material-1',
        action: 'APPROVE',
        expectedRevision: 4,
        accessToken: 'session-token',
        role: 'MODERATOR',
        idempotencyKey: 'decision-key',
      })
    ).rejects.toMatchObject({
      status: 403,
      message: expect.stringContaining('permisos administrativos'),
    });
  });

  it('exige reason para rechazo', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          id: 'operation-2',
          state: 'APPLIED',
          result: { status: 'REJECTED' },
          failure: null,
        }),
    } as unknown as Response);

    await submitModerationDecision({
      materialId: 'material-1',
      action: 'REJECT',
      reason: 'Contenido inapropiado',
      expectedRevision: 5,
      accessToken: 'session-token',
      role: 'ADMIN',
      idempotencyKey: 'decision-key-2',
    });

    expect(vi.mocked(window.fetch).mock.calls[0][1]?.body).toBe(
      JSON.stringify({
        action: 'REJECT',
        expectedRevision: 5,
        reason: 'Contenido inapropiado',
      })
    );
  });
});
