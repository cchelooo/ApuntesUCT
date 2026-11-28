import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { CatalogModule } from '../src/presentation/catalog/catalog.module';
import { CatalogService } from '../src/application/services/catalog.service';
import { accessToken, jwtSettings } from './authorization-fixture';

describe('Autorización directa de Catalog', () => {
  let app: INestApplication;
  const write = jest.fn(() => ({}));
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          load: [() => jwtSettings],
        }),
        CatalogModule,
      ],
      providers: [],
    })
      .overrideProvider(CatalogService)
      .useValue({
        listUniversities: () => [],
        createUniversity: write,
        deleteUniversity: write,
        createCareer: write,
        deleteCareer: write,
        createSubject: write,
        deleteSubject: write,
        createProfessor: write,
        deleteProfessor: write,
      })
      .compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    await app.init();
  });
  afterAll(async () => {
    await app?.close();
  });
  beforeEach(() => write.mockClear());

  it('mantiene las lecturas públicas', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/catalog/universities')
      .expect(200);
  });
  it.each(['universities', 'careers', 'subjects', 'professors'])(
    'protege creación y eliminación de %s',
    async (resource) => {
      for (const method of ['post', 'delete'] as const) {
        const path =
          '/api/v1/catalog/' + resource + (method === 'delete' ? '/id' : '');
        for (const [token, status] of [
          ['', 401],
          [accessToken('STUDENT'), 403],
          [accessToken('MODERATOR'), 403],
          [accessToken('ADMIN', { exp: 1 }), 401],
          [accessToken('ADMIN', {}, true), 401],
          [accessToken('ADMIN', { role: undefined }), 403],
          [accessToken(), method === 'post' ? 201 : 200],
        ] as const) {
          const client = request(app.getHttpServer());
          await client[method](path)
            .set('Authorization', token ? 'Bearer ' + token : '')
            .set('X-User-Role', 'ADMIN')
            .send({ role: 'ADMIN' })
            .expect(status);
        }
        expect(write).toHaveBeenCalledTimes(1);
        write.mockClear();
      }
    },
  );
});
