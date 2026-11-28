import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
@Catch()
export class QualityErrorFilter implements ExceptionFilter {
  catch(e: unknown, host: ArgumentsHost) {
    const req = host.switchToHttp().getRequest<Request>(),
      res = host.switchToHttp().getResponse<Response>();
    const persistence =
      !!e && typeof e === 'object' && 'name' in e && String(e.name).startsWith('Prisma');
    const status = e instanceof HttpException ? e.getStatus() : persistence ? 503 : 500;
    const raw = e instanceof HttpException ? e.getResponse() : null;
    const body = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
    if (!req.path.startsWith('/api/v1/quality')) {
      res.status(status).json(raw ?? { statusCode: status, message: 'Internal server error' });
      return;
    }
    const names: Record<number, string> = {
      400: 'VALIDATION_ERROR',
      401: 'UNAUTHENTICATED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      503: 'DEPENDENCY_UNAVAILABLE',
    };
    if (status === 401) res.setHeader('WWW-Authenticate', 'Bearer');
    const message =
      typeof body.message === 'string'
        ? body.message
        : Array.isArray(body.message)
          ? body.message.join('; ')
          : typeof raw === 'string'
            ? raw
            : 'No se pudo completar la solicitud.';
    res.status(status).json({
      statusCode: status,
      code: typeof body.code === 'string' ? body.code : (names[status] ?? 'INTERNAL_ERROR'),
      message,
      requestId: res.getHeader('X-Request-Id') ?? randomUUID(),
    });
  }
}
