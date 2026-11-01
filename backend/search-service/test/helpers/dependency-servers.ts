import { createServer, Server, ServerResponse } from 'node:http';
import { AddressInfo } from 'node:net';
import { catalogFixture, materialsFixture, PublishedMaterial } from './search-fixtures';

export type DependencyName = 'catalog' | 'material';
export type Fault =
  | { kind: 'none' }
  | { kind: 'http'; status: number }
  | { kind: 'invalid-json' }
  | { kind: 'disconnect' }
  | { kind: 'timeout-headers' }
  | { kind: 'timeout-body' };

export interface FixturePage {
  items: PublishedMaterial[];
  page: number;
  pageSize: number;
  total: number;
}

/** Servidores HTTP locales: no se reemplazan fetch, puertos ni adaptadores de Search. */
export class DependencyServers {
  materials: PublishedMaterial[] = [];
  catalog: unknown = [];
  faults: Record<DependencyName, Fault> = { catalog: { kind: 'none' }, material: { kind: 'none' } };
  calls: Record<DependencyName, string[]> = { catalog: [], material: [] };
  materialResponse?: (page: FixturePage) => unknown;
  urls = { catalog: '', material: '' };
  private servers: Server[] = [];

  reset(): void {
    this.materials = materialsFixture();
    this.catalog = catalogFixture();
    this.faults = { catalog: { kind: 'none' }, material: { kind: 'none' } };
    this.calls = { catalog: [], material: [] };
    this.materialResponse = undefined;
  }

  async start(): Promise<void> {
    this.reset();
    // Registrar cada servidor antes de escuchar permite limpiar un arranque parcial.
    for (const name of ['catalog', 'material'] as const) {
      const server = createServer((req, res) => {
        this.calls[name].push(req.url ?? '');
        const url = new URL(req.url ?? '/', 'http://fixture.local');
        const expectedPath = name === 'catalog' ? '/api/v1/catalog/filter' : '/api/v1/materials';
        if (url.pathname !== expectedPath || req.method !== 'GET') {
          res.statusCode = 404;
          res.end('Ruta inesperada');
          return;
        }
        const fault = this.faults[name];
        if (fault.kind === 'disconnect') {
          req.socket.destroy();
          return;
        }
        if (fault.kind === 'timeout-headers') return;
        if (fault.kind === 'timeout-body') {
          res.writeHead(200, { 'content-type': 'application/json' });
          res.write('{"incomplete":');
          return;
        }
        if (fault.kind === 'http') {
          this.json(res, { message: 'PRIVATE_UPSTREAM_DETAIL' }, fault.status);
          return;
        }
        if (fault.kind === 'invalid-json') {
          res.writeHead(200, { 'content-type': 'application/json' });
          res.end('PRIVATE_UPSTREAM_DETAIL: no es JSON');
          return;
        }
        if (name === 'catalog') {
          this.json(res, this.catalog);
          return;
        }
        const page = Number(url.searchParams.get('page'));
        const pageSize = Number(url.searchParams.get('pageSize'));
        if (
          !Number.isInteger(page) ||
          page < 1 ||
          !Number.isInteger(pageSize) ||
          pageSize < 1 ||
          pageSize > 100
        ) {
          this.json(res, { message: 'Paginación de fixture inválida' }, 400);
          return;
        }
        // Emula el orden contractual del listado público de Material.
        const ordered = [...this.materials].sort((a, b) => {
          const date = Date.parse(b.createdAt) - Date.parse(a.createdAt);
          return date || (a.id < b.id ? 1 : a.id > b.id ? -1 : 0);
        });
        const result: FixturePage = {
          items: ordered.slice((page - 1) * pageSize, page * pageSize),
          page,
          pageSize,
          total: ordered.length,
        };
        this.json(res, this.materialResponse ? this.materialResponse(result) : result);
      });
      this.servers.push(server);
      await new Promise<void>((resolve, reject) => {
        const onError = (error: Error) => reject(error);
        server.once('error', onError);
        server.listen(0, '127.0.0.1', () => {
          server.off('error', onError);
          resolve();
        });
      });
      this.urls[name] = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    }
  }

  closeConnections(): void {
    for (const server of this.servers) server.closeAllConnections();
  }

  async close(): Promise<void> {
    await Promise.all(
      this.servers.map(
        (server) =>
          new Promise<void>((resolve, reject) => {
            if (!server.listening) {
              resolve();
              return;
            }
            server.close((error) => (error ? reject(error) : resolve()));
            server.closeAllConnections();
          }),
      ),
    );
    this.servers = [];
  }

  private json(response: ServerResponse, payload: unknown, status = 200): void {
    response.writeHead(status, { 'content-type': 'application/json' });
    response.end(JSON.stringify(payload));
  }
}
