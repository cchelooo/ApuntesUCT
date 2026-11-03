import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { MaterialDetailResponse } from '../../domain/material/materialApi';
import { mapMaterialDetail } from './mapMaterialDetail';

const SUBJECT_ID = '44444444-4444-4444-8444-444444444444';
const PROFESSOR_ID = '55555555-5555-4555-8555-555555555555';
const GATEWAY = 'https://gateway.test/api/v1';

function detail(
  overrides: Partial<MaterialDetailResponse> = {}
): MaterialDetailResponse {
  return {
    id: '11111111-1111-4111-8111-111111111111',
    title: 'Certamen 1',
    description: 'Preguntas de años anteriores',
    uploaderId: '33333333-3333-4333-8333-333333333333',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    subjectId: SUBJECT_ID,
    professorId: PROFESSOR_ID,
    materialTypeId: '66666666-6666-4666-8666-666666666666',
    materialType: 'EXAM',
    academicYear: 2026,
    status: 'PUBLISHED',
    verified: false,
    externalLink: null,
    createdAt: '2026-10-01T12:00:00.000Z',
    updatedAt: '2026-10-01T12:00:00.000Z',
    currentVersion: {
      id: '22222222-2222-4222-8222-222222222222',
      versionNumber: 3,
      originalFilename: 'certamen.pdf',
      mimeType: 'application/pdf',
      fileSize: '15728640',
      createdAt: '2026-10-02T12:00:00.000Z',
    },
    ...overrides,
  };
}

describe('mapMaterialDetail (contrato real de GET /materials/:id)', () => {
  beforeEach(() => vi.stubEnv('VITE_API_URL', GATEWAY));
  afterEach(() => vi.unstubAllEnvs());

  it('mapea metadatos, versión actual y URL de descarga del Gateway', () => {
    const result = mapMaterialDetail(detail(), {
      subjects: { [SUBJECT_ID]: 'Estructuras de Datos' },
      professors: { [PROFESSOR_ID]: 'Carlos Ramírez' },
    });

    expect(result).toMatchObject({
      title: 'Certamen 1',
      description: 'Preguntas de años anteriores',
      type: 'EXAM',
      year: 2026,
      subjectName: 'Estructuras de Datos',
      professorName: 'Carlos Ramírez',
      downloadUrl:
        `${GATEWAY}/materials/11111111-1111-4111-8111-111111111111/download`,
    });
    expect(result.version).toMatchObject({
      number: 3,
      fileFormat: 'PDF',
      fileSizeLabel: '15.0 MB',
    });
    expect(result.version?.uploadedAt).not.toBeNull();
  });

  it('deja los nombres en null si el catálogo no está disponible', () => {
    const result = mapMaterialDetail(detail());
    expect(result.subjectName).toBeNull();
    expect(result.professorName).toBeNull();
  });

  it('sin currentVersion (enlace) no habilita la descarga', () => {
    const result = mapMaterialDetail(
      detail({ currentVersion: null, externalLink: 'https://example.com/x' })
    );
    expect(result.version).toBeNull();
    expect(result.downloadUrl).toBeNull();
  });
});
