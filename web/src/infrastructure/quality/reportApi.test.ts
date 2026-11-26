import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createMaterialReport, ReportRequestError } from './reportApi';

describe('createMaterialReport S3-16 contract', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_API_URL', 'https://gateway.test/api/v1');
    window.fetch = vi.fn();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
  });

  it('envía POST 201 y no ejecuta ninguna operación de retiro', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      status: 201,
      json: () =>
        Promise.resolve({
          id: 'report-1',
          status: 'OPEN',
        }),
    } as unknown as Response);

    const receipt = await createMaterialReport({
      materialId: 'material-1',
      reason: 'INCORRECT_INFORMATION',
      details: 'El año no coincide.',
      accessToken: 'session-token',
      idempotencyKey: 'report-key-1',
    });

    expect(receipt).toEqual({
      httpStatus: 201,
      reportId: 'report-1',
      status: 'OPEN',
    });
    expect(window.fetch).toHaveBeenCalledTimes(1);
    const [url, init] = vi.mocked(window.fetch).mock.calls[0];
    expect(url).toBe(
      'https://gateway.test/api/v1/quality/materials/material-1/reports'
    );
    expect(init).toEqual(
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer session-token',
          'Idempotency-Key': 'report-key-1',
        }),
      })
    );
    expect(String(init?.body)).not.toContain('RETIRED');
  });

  it('reconoce replay HTTP 200 como el reporte existente', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          id: 'report-existing',
          status: 'IN_REVIEW',
        }),
    } as unknown as Response);

    const receipt = await createMaterialReport({
      materialId: 'material-1',
      reason: 'BROKEN_RESOURCE',
      accessToken: 'session-token',
      idempotencyKey: 'same-key',
    });

    expect(receipt.httpStatus).toBe(200);
    expect(receipt.reportId).toBe('report-existing');
  });

  it('rechaza 409 REPORT_ALREADY_OPEN sin retirar el material', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: false,
      status: 409,
    } as Response);

    await expect(
      createMaterialReport({
        materialId: 'material-1',
        reason: 'COPYRIGHT',
        accessToken: 'session-token',
        idempotencyKey: 'other-key',
      })
    ).rejects.toMatchObject({ status: 409 });

    expect(window.fetch).toHaveBeenCalledTimes(1);
  });

  it('exige explicación para OTHER', async () => {
    await expect(
      createMaterialReport({
        materialId: 'material-1',
        reason: 'OTHER',
        accessToken: 'session-token',
        idempotencyKey: 'other-key',
      })
    ).rejects.toBeInstanceOf(ReportRequestError);
    expect(window.fetch).not.toHaveBeenCalled();
  });
});
