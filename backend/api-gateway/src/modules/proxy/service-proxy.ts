import type { RequestHandler } from 'express';
import { createProxyServer } from 'httpxy';
import { Readable } from 'node:stream';
import { stringify } from 'node:querystring';

/** Nest selects the routes; no user-controlled glob patterns are evaluated. */
export function serviceProxy(
  target: string,
  serviceName: string,
  rewritePath: (path: string) => string = (path) => path,
): RequestHandler {
  const proxy = createProxyServer({
    target,
    changeOrigin: true,
    proxyTimeout: 5000,
  });

  return (req, res) => {
    req.url = rewritePath(req.originalUrl);
    // Nest has already consumed JSON/form bodies. Unparsed streams pass through.
    const contentType = req.headers['content-type']?.split(';')[0].trim();
    let body: string | undefined;
    if (req.body !== undefined && req.readableEnded) {
      if (
        contentType === 'application/json' ||
        contentType?.endsWith('+json')
      ) {
        body = JSON.stringify(req.body);
      } else if (contentType === 'application/x-www-form-urlencoded') {
        body = stringify(req.body);
      }
    }
    if (body !== undefined) {
      req.headers['content-length'] = String(Buffer.byteLength(body));
      // Parsed bodies are decoded: forward the reconstructed body without encoding.
      delete req.headers['content-encoding'];
      delete req.headers['transfer-encoding'];
    }
    void proxy
      .web(req, res, {
        ...(body !== undefined ? { buffer: Readable.from([body]) } : {}),
      })
      .catch(() => {
        if (res.headersSent) {
          res.destroy();
        } else if (!res.destroyed) {
          res
            .status(502)
            .json({ statusCode: 502, message: `${serviceName} no disponible` });
        }
      });
  };
}
