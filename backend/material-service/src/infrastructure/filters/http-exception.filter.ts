import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const exceptionResponse = exception instanceof HttpException ? exception.getResponse() : null;

    let message: string | string[] = 'Internal server error';
    let errorName = 'Internal Server Error';
    let field: string | undefined;

    if (typeof exceptionResponse === 'string') {
      message = exceptionResponse;
    } else if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
      const resObj = exceptionResponse as Record<string, unknown>;
      if (typeof resObj.message === 'string' && resObj.message) {
        message = resObj.message;
      } else if (
        Array.isArray(resObj.message) &&
        resObj.message.every((item: unknown) => typeof item === 'string')
      ) {
        message = resObj.message;
      }
      if (typeof resObj.error === 'string' && resObj.error) {
        errorName = resObj.error;
      }
      if (typeof resObj.field === 'string' && resObj.field) {
        field = resObj.field;
      }
    }

    if (request.path.startsWith('/internal/v1/quality')) {
      const data = (
        exceptionResponse && typeof exceptionResponse === 'object' ? exceptionResponse : {}
      ) as Record<string, unknown>;
      const codes: Record<number, string> = {
        400: 'VALIDATION_ERROR',
        401: 'UNAUTHENTICATED',
        403: 'FORBIDDEN',
        404: 'NOT_FOUND',
        409: 'CONFLICT',
        503: 'DEPENDENCY_UNAVAILABLE',
      };
      if (status === 401) response.setHeader('WWW-Authenticate', 'Bearer');
      response
        .status(status)
        .json({
          statusCode: status,
          code: typeof data.code === 'string' ? data.code : (codes[status] ?? 'INTERNAL_ERROR'),
          message: Array.isArray(message) ? message.join('; ') : message,
          requestId: response.getHeader('X-Request-Id'),
        });
      return;
    }
    response.status(status).json({
      statusCode: status,
      error: errorName,
      message,
      ...(field !== undefined ? { field } : {}),
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
