import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';
import { ServiceContext, verifyService, fault } from './service-assertion';
export type InternalRequest = Request & { serviceContext: ServiceContext; requestId?: string };
@Injectable()
export class QualityServiceGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<InternalRequest>();
    const apply = req.method === 'PUT' || req.path.includes('/decisions/');
    const c = verifyService(
      req.headers.authorization,
      process.env.QUALITY_SERVICE_PUBLIC_KEY,
      'material-service',
      apply ? 'material:quality:apply' : 'material:review:read',
      req.originalUrl,
      req.method === 'PUT' ? req.body : null,
    );
    req.serviceContext = c;
    if (!['MODERATOR', 'ADMIN'].includes(c.actorRole))
      throw fault(403, 'FORBIDDEN', 'Se requiere un moderador.');
    if (apply && c.operationId !== req.params.operationId)
      throw fault(403, 'FORBIDDEN', 'Operación no vinculada.');
    return true;
  }
}
