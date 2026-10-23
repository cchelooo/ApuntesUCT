import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { MaterialController } from '../src/presentation/controllers/material.controller';
import { CreateMaterial } from '../src/application/use-cases/create-material';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';
import { CatalogPort } from '../src/application/ports/catalog.port';
import { CatalogHttpAdapter } from '../src/infrastructure/catalog/catalog-http.adapter';
import { setupApp } from '../src/setup-app';
import { academicIds, catalogTree, catalogProfessors } from './catalog-fixtures';

describe('POST /materials - referencias mediante Catalog', () => {
  let app: INestApplication;
  let fetchSpy: jest.SpyInstance;
  const prisma = {
    materialType: { findFirst: jest.fn() },
    material: { create: jest.fn() },
    materialVersion: { findFirst: jest.fn() },
  };
  const storage = { save: jest.fn(), remove: jest.fn() };
  const authorProvider = { resolve: jest.fn() };
  const metadata = () => ({
    title: 'Guía de cálculo',
    year: '2026',
    subjectId: academicIds.subject,
    type: 'LINK',
    externalLink: 'https://example.com/apunte',
  });
  const config = new ConfigService({
    catalog: { baseUrl: 'http://localhost:3002/api/v1', timeoutMs: 5000 },
  });
  const doc = readFileSync(join(__dirname, 'fixtures', 'valid-document.doc'));

  const postLink = (fields: Record<string, string> = metadata()) =>
    request(app.getHttpServer()).post('/api/v1/materials').field(fields);
  const postDocument = () =>
    request(app.getHttpServer())
      .post('/api/v1/materials')
      .field({ title: 'Documento', year: '2026', subjectId: academicIds.subject, type: 'DOCUMENT' })
      .attach('file', doc, { filename: 'documento.doc', contentType: 'application/msword' });
  const noWrites = () => {
    expect(storage.save).not.toHaveBeenCalled();
    expect(storage.remove).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [MaterialController],
      providers: [
        CreateMaterial,
        { provide: PrismaService, useValue: prisma },
        { provide: ObjectStorage, useValue: storage },
        { provide: MaterialAuthorProvider, useValue: authorProvider },
        { provide: ConfigService, useValue: config },
        { provide: CatalogPort, useClass: CatalogHttpAdapter },
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    authorProvider.resolve.mockReturnValue({ id: academicIds.author, universityId: null });
    prisma.materialType.findFirst.mockResolvedValue({ id: academicIds.other });
    prisma.material.create.mockImplementation(({ data }) =>
      Promise.resolve({ ...data, id: academicIds.other, createdAt: new Date() }),
    );
    storage.save.mockResolvedValue({ storageKey: 'materials/catalog-valid-file' });
    fetchSpy = jest.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
      const url = new URL(String(input));
      return new Response(
        JSON.stringify(url.pathname.endsWith('/professors') ? catalogProfessors() : catalogTree()),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      );
    });
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });
  afterAll(async () => {
    await app.close();
  });

  it('crea LINK con solo asignatura válida, sin exigir carrera/universidad', async () => {
    await postLink().expect(201);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(String(fetchSpy.mock.calls[0][0])).toBe('http://localhost:3002/api/v1/catalog');
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          careerId: null,
          universityId: null,
          subjectId: academicIds.subject,
        }),
      }),
    );
  });

  it('acepta carrera, universidad del autor y profesor compatibles', async () => {
    authorProvider.resolve.mockReturnValue({
      id: academicIds.author,
      universityId: academicIds.university,
    });
    await postLink({
      ...metadata(),
      careerId: academicIds.career,
      professorId: academicIds.professor,
    }).expect(201);
    const url = new URL(String(fetchSpy.mock.calls[1][0]));
    expect(url.pathname).toBe('/api/v1/catalog/professors');
    expect(url.searchParams.get('subjectId')).toBe(academicIds.subject);
    expect(prisma.material.create).toHaveBeenCalledTimes(1);
  });

  it('almacena un DOC real solo después de validar Catalog', async () => {
    await postDocument().expect(201);
    expect(storage.save).toHaveBeenCalledWith(doc, 'application/msword');
    expect(fetchSpy.mock.invocationCallOrder[0]).toBeLessThan(
      storage.save.mock.invocationCallOrder[0],
    );
    expect(prisma.material.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          versions: {
            create: expect.objectContaining({
              storageKey: 'materials/catalog-valid-file',
              fileSize: BigInt(doc.length),
            }),
          },
        }),
      }),
    );
  });

  it('espera la respuesta de Catalog antes de almacenar', async () => {
    let entered!: () => void;
    let release!: (response: Response) => void;
    const enteredPromise = new Promise<void>((resolve) => {
      entered = resolve;
    });
    const pending = new Promise<Response>((resolve) => {
      release = resolve;
    });
    fetchSpy.mockImplementationOnce(() => {
      entered();
      return pending;
    });
    const result = postDocument().then((response) => response);
    await enteredPromise;
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
    release(new Response(JSON.stringify(catalogTree()), { status: 200 }));
    expect((await result).status).toBe(201);
  });

  it('rechaza asignatura inexistente con 400 sin almacenar el DOC', async () => {
    fetchSpy.mockResolvedValueOnce(new Response('[]', { status: 200 }));
    const { body } = await postDocument().expect(400);
    expect(body.field).toBe('subjectId');
    noWrites();
  });

  it('valida también las referencias de LINK', async () => {
    await postLink({ ...metadata(), subjectId: academicIds.other }).expect(400);
    noWrites();
  });

  it('rechaza una carrera que no contiene la asignatura', async () => {
    const { body } = await postLink({ ...metadata(), careerId: academicIds.other }).expect(400);
    expect(body.field).toBe('careerId');
    noWrites();
  });

  it('rechaza una universidad del autor incompatible', async () => {
    authorProvider.resolve.mockReturnValue({
      id: academicIds.author,
      universityId: academicIds.other,
    });
    const { body } = await postLink().expect(400);
    expect(body.field).toBe('universityId');
    noWrites();
  });

  it('rechaza un profesor no vinculado a la asignatura', async () => {
    fetchSpy.mockResolvedValueOnce(new Response(JSON.stringify(catalogTree()), { status: 200 }));
    fetchSpy.mockResolvedValueOnce(new Response('[]', { status: 200 }));
    const { body } = await postLink({ ...metadata(), professorId: academicIds.professor }).expect(
      400,
    );
    expect(body.field).toBe('professorId');
    noWrites();
  });

  it('rechaza un profesor inactivo aunque aparezca en la respuesta', async () => {
    fetchSpy.mockResolvedValueOnce(new Response(JSON.stringify(catalogTree()), { status: 200 }));
    fetchSpy.mockResolvedValueOnce(
      new Response(JSON.stringify([{ ...catalogProfessors()[0], active: false }]), { status: 200 }),
    );
    await postLink({ ...metadata(), professorId: academicIds.professor }).expect(400);
    noWrites();
  });

  it('rechaza UUID académico mal formado antes de llamar a Catalog', async () => {
    await postLink({ ...metadata(), subjectId: 'SUBJ-101' }).expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
    noWrites();
  });

  it('devuelve 502 ante un fallo de red, sin almacenar el DOC', async () => {
    fetchSpy.mockRejectedValueOnce(new Error('detalle privado de red'));
    const { body } = await postDocument().expect(502);
    expect(JSON.stringify(body)).not.toContain('detalle privado');
    noWrites();
  });

  it('devuelve 502 ante timeout', async () => {
    fetchSpy.mockRejectedValueOnce(new DOMException('timeout privado', 'TimeoutError'));
    await postDocument().expect(502);
    noWrites();
  });

  it.each([400, 404, 500, 503])(
    'trata HTTP %i de Catalog como fallo de dependencia',
    async (status) => {
      fetchSpy.mockResolvedValueOnce(new Response('respuesta privada', { status }));
      await postDocument().expect(502);
      noWrites();
    },
  );

  it('rechaza una respuesta de Catalog con estructura inválida con 502', async () => {
    fetchSpy.mockResolvedValueOnce(
      new Response(JSON.stringify({ unexpected: true }), { status: 200 }),
    );
    await postDocument().expect(502);
    noWrites();
  });

  it('no consulta Catalog para un tipo local inexistente', async () => {
    prisma.materialType.findFirst.mockResolvedValueOnce(null);
    await postLink().expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
    noWrites();
  });

  it.each(['title', 'subjectId', 'year', 'type'])(
    'rechaza ausencia de %s antes de procesar',
    async (field) => {
      const fields: Record<string, string> = metadata();
      delete fields[field];
      await postLink(fields).expect(400);
      expect(fetchSpy).not.toHaveBeenCalled();
      noWrites();
    },
  );

  it.each(['202', '20AB', '2026.5'])('rechaza año %s antes de llamar a Catalog', async (year) => {
    await postLink({ ...metadata(), year }).expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
    noWrites();
  });

  it('rechaza tipo fuera del enum antes de llamar a Catalog', async () => {
    await postLink({ ...metadata(), type: 'INVALID_TYPE' }).expect(400);
    expect(fetchSpy).not.toHaveBeenCalled();
    noWrites();
  });
});
