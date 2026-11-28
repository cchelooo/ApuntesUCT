import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { Actor, moderator } from './report-contract';
import { ReportDependencies } from './report-dependencies';
export type ReportRequest = Request & { actor: Actor };
@Injectable()
export class ReportGuard implements CanActivate {
  constructor(
    private readonly deps: ReportDependencies,
    private readonly reflector: Reflector,
  ) {}
  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest<ReportRequest>();
    req.actor = await this.deps.identity(req.headers.authorization);
    if (this.reflector.get<boolean>('reportAdmin', context.getHandler())) moderator(req.actor);
    return true;
  }
}
