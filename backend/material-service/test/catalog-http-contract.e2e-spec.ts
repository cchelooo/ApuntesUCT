import { ConfigService } from '@nestjs/config';
import { createServer, Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { CatalogHttpAdapter } from '../src/infrastructure/catalog/catalog-http.adapter';
import {
  CatalogUnavailableError,
  InvalidAcademicReferenceError,
} from '../src/application/ports/catalog.port';
import { academicIds, catalogTree, catalogProfessors } from './catalog-fixtures';

describe('CatalogHttpAdapter - contrato HTTP real con servidor local de prueba', () => {
  let server: Server;
  let adapter: CatalogHttpAdapter;
  let baseUrl: string;
  let status: number;
  let tree: unknown;
  let professors: unknown;
  let invalidJson: boolean;
  let hang: boolean;
  let requests: string[];

  beforeAll(async () => {
    server = createServer((req, res) => {
      requests.push(req.url ?? '');
      if (hang) return;
      res.statusCode = status;
      res.setHeader('Content-Type', 'application/json');
      res.end(
        invalidJson
          ? 'not-json'
          : JSON.stringify(req.url?.startsWith('/api/v1/catalog/professors') ? professors : tree),
      );
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address() as AddressInfo;
    baseUrl = `http://127.0.0.1:${port}/api/v1`;
  });

  beforeEach(() => {
    status = 200;
    tree = catalogTree();
    professors = catalogProfessors();
    invalidJson = false;
    hang = false;
    requests = [];
    adapter = new CatalogHttpAdapter(
      new ConfigService({ catalog: { baseUrl: `${baseUrl}/`, timeoutMs: 1000 } }),
    );
  });

  afterAll(async () => {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  });

  const references = () => ({ subjectId: academicIds.subject, universityId: null });

  it('respeta /api/v1, tolera barra final y valida relaciones por HTTP', async () => {
    await adapter.validateReferences({
      ...references(),
      careerId: academicIds.career,
      universityId: academicIds.university,
      professorId: academicIds.professor,
    });
    expect(requests).toEqual([
      '/api/v1/catalog',
      `/api/v1/catalog/professors?subjectId=${academicIds.subject}`,
    ]);
  });

  it('no exige las referencias opcionales ni consulta profesores si no hay professorId', async () => {
    await adapter.validateReferences(references());
    expect(requests).toEqual(['/api/v1/catalog']);
  });

  it('rechaza árbol vacío como referencia inválida', async () => {
    tree = [];
    await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
      InvalidAcademicReferenceError,
    );
  });

  it.each(['university', 'career', 'subject'])(
    'rechaza una jerarquía con %s inactiva',
    async (level) => {
      const data = catalogTree();
      if (level === 'university') data[0].active = false;
      if (level === 'career') data[0].careers[0].active = false;
      if (level === 'subject') data[0].careers[0].subjects[0].active = false;
      tree = data;
      await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
        InvalidAcademicReferenceError,
      );
    },
  );

  it.each([
    {},
    null,
    [{ id: academicIds.university, active: true }],
    [
      {
        id: academicIds.university,
        active: true,
        careers: [{ id: academicIds.career, active: true }],
      },
    ],
    [{ id: academicIds.university, active: 'true', careers: [] }],
  ])('rechaza una estructura de árbol mal formada: %j', async (value) => {
    tree = value;
    await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
      CatalogUnavailableError,
    );
  });

  it('rechaza identificadores duplicados en el árbol como fallo del contrato', async () => {
    const data = catalogTree();
    data[0].careers[0].subjects.push({ ...data[0].careers[0].subjects[0] });
    tree = data;
    await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
      CatalogUnavailableError,
    );
  });

  it('rechaza JSON inválido como fallo de dependencia', async () => {
    invalidJson = true;
    await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
      CatalogUnavailableError,
    );
  });

  it.each([400, 404, 500, 503])(
    'rechaza HTTP %i sin confundirlo con asignatura inexistente',
    async (code) => {
      status = code;
      await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
        CatalogUnavailableError,
      );
    },
  );

  it('aborta una petición HTTP real que excede el timeout', async () => {
    hang = true;
    adapter = new CatalogHttpAdapter(new ConfigService({ catalog: { baseUrl, timeoutMs: 50 } }));
    await expect(adapter.validateReferences(references())).rejects.toBeInstanceOf(
      CatalogUnavailableError,
    );
  });

  it('rechaza respuesta mal formada del contrato de profesores', async () => {
    professors = { items: catalogProfessors() };
    await expect(
      adapter.validateReferences({ ...references(), professorId: academicIds.professor }),
    ).rejects.toBeInstanceOf(CatalogUnavailableError);
  });

  it('rechaza IDs mal formados sin hacer peticiones HTTP', async () => {
    await expect(
      adapter.validateReferences({ subjectId: 'SUBJ-101', universityId: null }),
    ).rejects.toBeInstanceOf(InvalidAcademicReferenceError);
    expect(requests).toEqual([]);
  });

  it.each(['careerId', 'professorId', 'universityId'] as const)(
    'valida UUID opcional %s cuando se proporciona',
    async (field) => {
      await expect(
        adapter.validateReferences({ ...references(), [field]: 'invalid-id' }),
      ).rejects.toBeInstanceOf(InvalidAcademicReferenceError);
      expect(requests).toEqual([]);
    },
  );

  it.each([0, -1, 1.5, 'abc'])('rechaza timeout de configuración inválido: %s', (timeoutMs) => {
    expect(
      () => new CatalogHttpAdapter(new ConfigService({ catalog: { baseUrl, timeoutMs } })),
    ).toThrow('CATALOG_TIMEOUT_MS');
  });

  it('rechaza protocolos ajenos a HTTP(S)', () => {
    expect(
      () =>
        new CatalogHttpAdapter(
          new ConfigService({ catalog: { baseUrl: 'file:///tmp/catalog', timeoutMs: 1000 } }),
        ),
    ).toThrow('CATALOG_SERVICE_URL');
  });
});
