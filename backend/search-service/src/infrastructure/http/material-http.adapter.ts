import { Injectable } from '@nestjs/common';
import { DependencyError } from '../../application/errors/dependency.error';
import {
  MaterialCandidate,
  MaterialPage,
  MaterialPageQuery,
  MaterialPort,
} from '../../application/ports/material.port';
import { getJson } from './http-client';
import {
  isInteger,
  isIsoDateString,
  isNonEmptyString,
  isNullableString,
  isRecord,
} from './payload-validators';

const MATERIAL_SERVICE = 'Material Service';

function invalidResponse(message: string, cause?: unknown): DependencyError {
  return new DependencyError(MATERIAL_SERVICE, 'invalid-response', message, {
    cause,
  });
}

function toCandidate(item: unknown): MaterialCandidate {
  if (
    !isRecord(item) ||
    !isNonEmptyString(item.id) ||
    !isNonEmptyString(item.title) ||
    !isNullableString(item.description) ||
    !isNonEmptyString(item.materialType) ||
    !isInteger(item.academicYear) ||
    typeof item.verified !== 'boolean' ||
    !isNonEmptyString(item.subjectId) ||
    !isNullableString(item.careerId) ||
    !isNullableString(item.universityId) ||
    !isNullableString(item.professorId) ||
    !isIsoDateString(item.createdAt) ||
    !isIsoDateString(item.updatedAt)
  ) {
    throw invalidResponse(
      'Material Service devolvió un material con campos inválidos',
    );
  }

  return {
    id: item.id,
    title: item.title,
    description: item.description,
    materialType: item.materialType,
    academicYear: item.academicYear,
    verified: item.verified,
    subjectId: item.subjectId,
    careerId: item.careerId,
    universityId: item.universityId,
    professorId: item.professorId,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

@Injectable()
export class MaterialHttpAdapter extends MaterialPort {
  private readonly baseUrl =
    process.env.MATERIAL_SERVICE_URL ?? 'http://127.0.0.1:3003';

  async findCandidates(query: MaterialPageQuery): Promise<MaterialPage> {
    const url = new URL('/api/v1/materials', this.baseUrl);
    url.searchParams.set('page', String(query.page));
    url.searchParams.set('pageSize', String(query.pageSize));

    const payload = await getJson<unknown>(url.toString(), MATERIAL_SERVICE);

    if (
      !isRecord(payload) ||
      !Array.isArray(payload.items) ||
      !isInteger(payload.page) ||
      payload.page < 1 ||
      !isInteger(payload.pageSize) ||
      payload.pageSize < 1 ||
      payload.pageSize > 100 ||
      !isInteger(payload.total) ||
      payload.total < 0
    ) {
      throw invalidResponse(
        'Material Service devolvió una página con campos inválidos',
      );
    }

    try {
      return {
        items: payload.items.map((item) => toCandidate(item)),
        page: payload.page,
        pageSize: payload.pageSize,
        total: payload.total,
      };
    } catch (error) {
      if (error instanceof DependencyError) {
        throw error;
      }

      throw invalidResponse(
        'Material Service devolvió un formato inesperado para el listado',
        error,
      );
    }
  }
}
