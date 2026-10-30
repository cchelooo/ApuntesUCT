import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { OpenAPIObject } from '@nestjs/swagger';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { SearchResponseDto } from '../src/application/dtos/search-response.dto';
import { setupApp } from '../src/setup-app';
import { DependencyServers } from './helpers/dependency-servers';
import { catalogFixture, ids, material, uuid } from './helpers/search-fixtures';

type Query = Record<string, string | number | string[]>;
const academic = { universityId: ids.university, careerId: ids.career, subjectId: ids.subject };
const expectedIds = (...values: number[]): string[] => values.map((value) => uuid(1000 + value));

describe('Search HTTP (Nest y adaptadores reales; dependencias HTTP locales)', () => {
  let app: INestApplication<Server> | undefined;
  const dependencies = new DependencyServers();
  const previousEnv: Record<string, string | undefined> = {};
  const envKeys = ['CATALOG_SERVICE_URL', 'MATERIAL_SERVICE_URL'] as const;

  beforeAll(async () => {
    for (const key of envKeys) previousEnv[key] = process.env[key];
    await dependencies.start();
    // Los adaptadores capturan las URL al instanciarse; configurar antes de compile().
    process.env.CATALOG_SERVICE_URL = dependencies.urls.catalog;
    process.env.MATERIAL_SERVICE_URL = dependencies.urls.material;
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication<INestApplication<Server>>();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => dependencies.reset());
  afterEach(() => dependencies.closeConnections());
  afterAll(async () => {
    try {
      if (app) await app.close();
    } finally {
      try {
        await dependencies.close();
      } finally {
        for (const key of envKeys) {
          if (previousEnv[key] === undefined) delete process.env[key];
          else process.env[key] = previousEnv[key];
        }
      }
    }
  });

  function server(): Server {
    if (!app) throw new Error('La aplicación no está inicializada');
    return app.getHttpServer();
  }

  function search(query: Query = {}) {
    return request(server()).get('/api/v1/search').query(query);
  }

  async function result(query: Query = {}): Promise<SearchResponseDto> {
    const response = await search(query).expect(200);
    return response.body as SearchResponseDto;
  }

  async function expectIds(query: Query, expected: string[]): Promise<SearchResponseDto> {
    const body = await result(query);
    expect(body.results.map((item) => item.id)).toEqual(expected);
    expect(body.total).toBe(expected.length);
    return body;
  }

  it('es público y conserva el contrato y los valores predeterminados', async () => {
    const body = await expectIds({}, expectedIds(7, 6, 5, 4, 3, 1, 2));
    expect(Object.keys(body).sort()).toEqual(
      ['query', 'page', 'pageSize', 'total', 'results', 'context'].sort(),
    );
    expect(body).toMatchObject({ query: null, page: 1, pageSize: 20 });
    expect(body.results.find((item) => item.id === uuid(1001))).toMatchObject({
      subjectName: 'Matemáticas',
      careerName: 'Informática',
      universityName: 'Universidad Uno',
      professorId: ids.professor,
      description: null,
      academicYear: 2026,
    });
    expect(dependencies.calls.catalog).toEqual(['/api/v1/catalog/filter']);
    expect(dependencies.calls.material).toEqual(['/api/v1/materials?page=1&pageSize=20']);
  });

  it.each(['algebra', 'ÁLGEBRA', '  álgebra  '])(
    'encuentra texto con q=%j en título o descripción',
    async (q) => {
      const body = await expectIds({ q }, expectedIds(3, 1, 2));
      expect(body.query).toBe(q.trim());
      expect(dependencies.calls.material).toEqual(['/api/v1/materials?page=1&pageSize=100']);
    },
  );

  it('encuentra una coincidencia exclusiva en descripción', async () => {
    await expectIds({ q: 'aplicaciones' }, expectedIds(2));
  });

  it.each(['', '   '])('q=%j conserva el listado y sus parámetros', async (q) => {
    const body = await result({ q, page: 2, pageSize: 2 });
    expect(body).toMatchObject({ query: null, page: 2, pageSize: 2, total: 7 });
    expect(body.results.map((item) => item.id)).toEqual(expectedIds(5, 4));
    expect(dependencies.calls.material).toEqual(['/api/v1/materials?page=2&pageSize=2']);
  });

  it('texto inexistente devuelve un contrato vacío, no un error', async () => {
    const body = await result({ q: 'sin-coincidencias-xyz' });
    expect(body).toEqual({
      query: 'sin-coincidencias-xyz',
      page: 1,
      pageSize: 20,
      total: 0,
      results: [],
      context: [],
    });
  });

  const filters: Array<[string, Query, number[]]> = [
    ['universidad', { universityId: ids.university }, [5, 3, 1, 2]],
    ['carrera', { universityId: ids.university, careerId: ids.career }, [5, 3, 1, 2]],
    ['asignatura', academic, [5, 3, 1, 2]],
    ['profesor', { ...academic, professorId: ids.professor }, [3, 1]],
    [
      'otro profesor de la misma asignatura',
      { ...academic, professorId: ids.secondProfessor },
      [2],
    ],
    ['año independiente', { year: 2026 }, [7, 6, 4, 3, 1]],
    ['tipo independiente', { type: 'DOCUMENT' }, [7, 6, 3, 1]],
    ['tipo dinámico ajeno al enum POST', { type: 'APUNTE' }, [5]],
    ['año y tipo', { year: 2026, type: 'DOCUMENT' }, [7, 6, 3, 1]],
    [
      'los seis filtros y texto',
      { ...academic, professorId: ids.professor, year: 2026, type: 'DOCUMENT', q: 'algebra' },
      [3, 1],
    ],
    ['q vacío con filtros', { q: '  ', year: 2025 }, [2]],
    ['type con espacios exteriores', { type: ' LINK ' }, [4]],
  ];
  it.each(filters)(
    'aplica filtro de %s y excluye los demás materiales',
    async (_label, query, expected) => {
      await expectIds(query, expectedIds(...expected));
    },
  );

  it.each([
    { universityId: ids.otherUniversity, careerId: ids.career },
    { ...academic, subjectId: ids.otherSubject },
    { ...academic, professorId: ids.otherProfessor },
    { universityId: uuid(999) },
    { year: 1900, type: 'DOCUMENT' },
    { type: 'TIPO_INEXISTENTE' },
  ])('una combinación completa sin coincidencias devuelve 200 vacío: %j', async (query) => {
    expect(await result(query)).toMatchObject({ total: 0, results: [], context: [] });
  });

  it('exige vínculo en Catalog además del professorId del material', async () => {
    const catalog = catalogFixture();
    catalog[0].professors = [];
    dependencies.catalog = catalog;
    expect(await result({ ...academic, professorId: ids.professor })).toMatchObject({
      total: 0,
      results: [],
      context: [],
    });
  });

  it('rellena referencias opcionales nulas desde Catalog', async () => {
    dependencies.materials = [material(1, { careerId: null, universityId: null })];
    const body = await expectIds(academic, expectedIds(1));
    expect(body.results[0]).toMatchObject({ careerId: ids.career, universityId: ids.university });
  });

  it('conserva materiales sin contexto al filtrar solo año', async () => {
    dependencies.catalog = [];
    const body = await expectIds({ year: 2026 }, expectedIds(7, 6, 4, 3, 1));
    expect(body.context).toEqual([]);
    expect(body.results.every((item) => item.subjectName === null)).toBe(true);
  });

  it('el adaptador y el DTO público no exponen campos adicionales de Material', async () => {
    dependencies.materialResponse = (page) => ({
      ...page,
      items: page.items.map((item) => ({
        ...item,
        storageKey: 'PRIVATE_STORAGE_KEY',
        checksum: 'PRIVATE_CHECKSUM',
      })),
    });
    const response = await search().expect(200);
    expect(response.text).not.toContain('PRIVATE_');
    expect(Object.keys((response.body as SearchResponseDto).results[0]).sort()).toEqual(
      [
        'id',
        'title',
        'description',
        'materialType',
        'academicYear',
        'verified',
        'subjectId',
        'careerId',
        'universityId',
        'professorId',
        'subjectName',
        'careerName',
        'universityName',
        'createdAt',
        'updatedAt',
      ].sort(),
    );
  });

  const invalid: Array<[string, Query]> = [
    ['carrera sin universidad', { careerId: ids.career }],
    ['asignatura sin carrera', { universityId: ids.university, subjectId: ids.subject }],
    [
      'profesor sin asignatura',
      { universityId: ids.university, careerId: ids.career, professorId: ids.professor },
    ],
    ['universidad inválida', { universityId: 'no-uuid' }],
    ['carrera inválida', { universityId: ids.university, careerId: 'no-uuid' }],
    ['asignatura inválida', { ...academic, subjectId: 'no-uuid' }],
    ['profesor inválido', { ...academic, professorId: 'no-uuid' }],
    ['año fuera de rango', { year: 2100 }],
    ['año vacío', { year: '' }],
    ['año decimal', { year: '2026.5' }],
    ['tipo vacío', { type: '  ' }],
    ['página cero', { page: 0 }],
    ['página excesiva', { page: '2147483648' }],
    ['página decimal', { page: '1.5' }],
    ['pageSize excesivo', { pageSize: 101 }],
    ['orden por valoración', { sortBy: 'rating' }],
    ['dirección inválida', { order: 'up' }],
    ['q excesivo', { q: 'x'.repeat(201) }],
    ['q repetido', { q: ['uno', 'dos'] }],
  ];
  it.each(invalid)('responde 400 antes de consultar dependencias: %s', async (_label, query) => {
    const response = await search(query).expect(400);
    expect(response.body).toHaveProperty('statusCode', 400);
    expect(dependencies.calls.catalog).toEqual([]);
    expect(dependencies.calls.material).toEqual([]);
  });

  it('conserva whitelist: los parámetros desconocidos se descartan', async () => {
    const base = await result();
    expect(await result({ unknownParameter: 'ignored' })).toEqual(base);
  });

  const orders: Array<[string, string, number[]]> = [
    ['createdAt', 'asc', [2, 3, 1, 4, 5, 6, 7]],
    ['createdAt', 'desc', [7, 6, 5, 4, 3, 1, 2]],
    ['title', 'asc', [3, 1, 2, 4, 7, 6, 5]],
    ['title', 'desc', [5, 6, 7, 4, 2, 3, 1]],
    ['year', 'asc', [5, 2, 7, 6, 4, 3, 1]],
    ['year', 'desc', [7, 6, 4, 3, 1, 2, 5]],
  ];
  it.each(orders)(
    'ordena globalmente por %s %s y desempata por id DESC',
    async (sortBy, order, expected) => {
      await expectIds({ sortBy, order }, expectedIds(...expected));
    },
  );

  it('repite una combinación con el mismo orden y total', async () => {
    const query = { year: 2026, type: 'DOCUMENT', sortBy: 'title', order: 'asc', pageSize: 2 };
    const first = await result(query);
    expect(await result(query)).toEqual(first);
  });

  it('pagina coincidencias con total estable y sin repetir IDs', async () => {
    const one = await result({ q: 'algebra', page: 1, pageSize: 2 });
    const two = await result({ q: 'algebra', page: 2, pageSize: 2 });
    expect(one).toMatchObject({ page: 1, pageSize: 2, total: 3 });
    expect(two).toMatchObject({ page: 2, pageSize: 2, total: 3 });
    expect(one.results.map((item) => item.id)).toEqual(expectedIds(3, 1));
    expect(two.results.map((item) => item.id)).toEqual(expectedIds(2));
    expect(new Set([...one.results, ...two.results].map((item) => item.id)).size).toBe(3);
  });

  it('página fuera de rango conserva total y contexto vacío', async () => {
    expect(await result({ q: 'algebra', page: 99 })).toMatchObject({
      page: 99,
      pageSize: 20,
      total: 3,
      results: [],
      context: [],
    });
  });

  it('context solo contiene las asignaturas de la página devuelta', async () => {
    const body = await result({ q: 'algebra', pageSize: 1 });
    expect(body.context.map((item) => item.subjectId)).toEqual([ids.subject]);
  });

  it('encuentra y pagina coincidencias de páginas posteriores de Material', async () => {
    dependencies.materials = Array.from({ length: 105 }, (_, i) =>
      material(i + 1, {
        title: i % 20 === 0 ? 'Hallazgo' : 'Otro material',
        createdAt: new Date(Date.UTC(2026, 9, 1) - i * 1000).toISOString(),
      }),
    );
    const body = await result({ q: 'hallazgo', year: 2026, page: 2, pageSize: 2 });
    expect(body.total).toBe(6);
    expect(body.results.map((item) => item.id)).toEqual(expectedIds(41, 61));
    expect(dependencies.calls.material).toEqual([
      '/api/v1/materials?page=1&pageSize=100',
      '/api/v1/materials?page=2&pageSize=100',
    ]);
  });

  it('ordena candidatos de varias páginas antes de seleccionar la primera', async () => {
    dependencies.materials = Array.from({ length: 101 }, (_, i) =>
      material(i + 1, {
        title: i === 100 ? 'Alfa' : 'Zeta',
        createdAt: new Date(Date.UTC(2026, 9, 1) - i * 1000).toISOString(),
      }),
    );
    const body = await result({ sortBy: 'title', order: 'asc', pageSize: 1 });
    expect(body.total).toBe(101);
    expect(body.results[0].id).toBe(uuid(1101));
    expect(dependencies.calls.material).toHaveLength(2);
  });

  it.each([{ q: 'algebra' }, { year: 2026 }, { sortBy: 'title' }])(
    'sobre el límite devuelve 503 y no resultados parciales: %j',
    async (query) => {
      dependencies.materials = Array.from({ length: 100 }, (_, i) => material(i + 1));
      dependencies.materialResponse = (page) => ({ ...page, total: 10001 });
      const response = await search(query).expect(503);
      expect(response.body).toMatchObject({
        statusCode: 503,
        message: 'La búsqueda supera el límite de materiales que puede procesarse.',
      });
      expect(response.body).not.toHaveProperty('results');
      expect(dependencies.calls.material).toHaveLength(1);
    },
  );

  it('el listado sin filtros no impone el límite del recorrido completo', async () => {
    dependencies.materialResponse = (page) => ({ ...page, total: 10001 });
    expect((await result()).total).toBe(10001);
    expect(dependencies.calls.material).toHaveLength(1);
  });

  it('una página incompleta durante la búsqueda produce 502', async () => {
    dependencies.materialResponse = (page) => ({ ...page, total: 100 });
    await search({ q: 'algebra' }).expect(502);
  });

  it.each(['total', 'duplicate'] as const)(
    'detecta inconsistencia entre páginas: %s',
    async (kind) => {
      dependencies.materials = Array.from({ length: 101 }, (_, i) => material(i + 1));
      dependencies.materialResponse = (page) => {
        if (page.page === 1) return page;
        return kind === 'total' ? { ...page, total: 102 } : { ...page, items: [material(101)] };
      };
      await search({ q: 'algebra' }).expect(502);
    },
  );

  for (const name of ['catalog', 'material'] as const) {
    const service = name === 'catalog' ? 'Catalog Service' : 'Material Service';
    describe(`fallos HTTP de ${service}`, () => {
      it.each([
        [400, 400],
        [422, 400],
        [403, 502],
        [500, 503],
        [503, 503],
      ])('traduce upstream %i a %i', async (status, expected) => {
        dependencies.faults[name] = { kind: 'http', status };
        const response = await search().expect(expected);
        expect(response.body).toHaveProperty('statusCode', expected);
        expect(response.text).toContain(service);
        expect(response.text).not.toContain('PRIVATE_UPSTREAM_DETAIL');
        expect(response.body).not.toHaveProperty('results');
      });

      it('conexión interrumpida produce 503 controlado', async () => {
        dependencies.faults[name] = { kind: 'disconnect' };
        const response = await search().expect(503);
        expect(response.body).toMatchObject({ message: `${service} no está disponible` });
      });

      it('JSON inválido produce 502 controlado', async () => {
        dependencies.faults[name] = { kind: 'invalid-json' };
        const response = await search().expect(502);
        expect(response.text).toContain(service);
        expect(response.text).not.toContain('PRIVATE_UPSTREAM_DETAIL');
      });

      it('estructura inválida produce 502', async () => {
        if (name === 'catalog') dependencies.catalog = { items: [] };
        else dependencies.materialResponse = () => ({ items: 'invalid' });
        await search().expect(502);
      });

      it('el timeout real de 5 s antes de recibir encabezados produce 503', async () => {
        dependencies.faults[name] = { kind: 'timeout-headers' };
        const response = await search().expect(503);
        expect(response.body).toMatchObject({
          message: `${service} no respondió dentro del tiempo esperado`,
        });
      });
    });
  }

  it('el timeout real durante la lectura del cuerpo de Material produce 503', async () => {
    dependencies.faults.material = { kind: 'timeout-body' };
    const response = await search().expect(503);
    expect(response.body).toMatchObject({
      message: 'Material Service no respondió dentro del tiempo esperado',
    });
  });

  it('una respuesta individual inválida de Material produce 502', async () => {
    dependencies.materialResponse = (page) => ({
      ...page,
      items: [{ ...material(1), verified: 'sí' }],
    });
    await search().expect(502);
  });

  it('un contexto sin universidad válida produce 502', async () => {
    dependencies.catalog = [
      { ...catalogFixture()[0], career: { id: ids.career, name: 'Carrera', university: null } },
    ];
    await search().expect(502);
  });

  it('la ruta health sigue operativa sin consultar dependencias', async () => {
    await request(server()).get('/api/v1/health').expect(200);
    expect(dependencies.calls.catalog).toEqual([]);
    expect(dependencies.calls.material).toEqual([]);
  });

  it('el OpenAPI servido por HTTP publica parámetros, errores y respuesta estable', async () => {
    const response = await request(server()).get('/api/docs-json').expect(200);
    const document = response.body as OpenAPIObject;
    const operation = document.paths['/api/v1/search'].get;
    const names = (operation.parameters ?? []).flatMap((parameter) =>
      '$ref' in parameter ? [] : [parameter.name],
    );
    expect(names.sort()).toEqual(
      [
        'q',
        'universityId',
        'careerId',
        'subjectId',
        'professorId',
        'year',
        'type',
        'sortBy',
        'order',
        'page',
        'pageSize',
      ].sort(),
    );
    expect(Object.keys(operation.responses)).toEqual(
      expect.arrayContaining(['200', '400', '502', '503']),
    );
    expect(operation.security ?? []).toEqual([]);
    expect(document.components?.schemas).toHaveProperty('SearchResponseDto');
    expect(operation.description).toContain('10.000');
    expect(operation.description).toContain('year y type son independientes');
  });
});
