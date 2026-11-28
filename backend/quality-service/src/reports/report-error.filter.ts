import { BaseExceptionFilter } from '@nestjs/core';
import type { Request } from 'express';
import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Response } from 'express';
@Catch()
export class ReportErrorFilter implements ExceptionFilter {
  catch(error: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    const status = error instanceof HttpException ? error.getStatus() : 503;
    const payload = error instanceof HttpException ? error.getResponse() : null;
    const body = payload && typeof payload === 'object' ? (payload as Record<string, unknown>) : {};
    if (status === 401) res.setHeader('WWW-Authenticate', 'Bearer');
    res.setHeader('Cache-Control', 'no-store');
    res.status(status).json({
      statusCode: status,
      code:
        body.code ??
        { 400: 'VALIDATION_ERROR', 401: 'UNAUTHENTICATED', 403: 'FORBIDDEN', 404: 'NOT_FOUND' }[
          status
        ] ??
        'DEPENDENCY_UNAVAILABLE',
      message:
        typeof body.message === 'string' ? body.message : 'No se pudo completar la solicitud.',
      requestId: randomUUID(),
    });
  }
}

/** Incluye errores del parser JSON sin cambiar el contrato de salud existente. */
@Catch()
export class ReportRoutingErrorFilter extends BaseExceptionFilter {
  private readonly reports = new ReportErrorFilter();
  catch(error: unknown, host: ArgumentsHost) {
    const req = host.switchToHttp().getRequest<Request>();
    if (/^\/api\/v1\/quality(?:[/?]|$)/.test(req.originalUrl))
      return this.reports.catch(error, host);
    return super.catch(error, host);
  }
}
