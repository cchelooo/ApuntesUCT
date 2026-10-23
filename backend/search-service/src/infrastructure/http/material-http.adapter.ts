import { Injectable } from '@nestjs/common';
import { DependencyError } from '../../application/errors/dependency.error';
import {
  MaterialCandidate,
  MaterialPage,
  MaterialPageQuery,
  MaterialPort,
} from '../../application/ports/material.port';
import { getJson } from './http-client';

const MATERIAL_SERVICE = 'Material Service';

interface MaterialItemPayload {
  id: string;
  title: string;
  description?: string | null;
  materialType?: string | null;
  academicYear?: number | null;
  verified?: boolean | null;
  subjectId?: string | null;
  careerId?: string | null;
  universityId?: string | null;
  professorId?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
}

interface MaterialPagePayload {
  items: MaterialItemPayload[];
  page: number;
  pageSize: number;
  total: number;
}

@Injectable()
export class MaterialHttpAdapter extends MaterialPort {
  private readonly baseUrl =
    process.env.MATERIAL_SERVICE_URL ?? 'http://127.0.0.1:3003';

  async findCandidates(query: MaterialPageQuery): Promise<MaterialPage> {
    const url = new URL('/api/v1/materials', this.baseUrl);
    url.searchParams.set('page', String(query.page));
    url.searchParams.set('pageSize', String(query.pageSize));

    const payload = await getJson<MaterialPagePayload>(
      url.toString(),
      MATERIAL_SERVICE,
    );

    if (
      !payload ||
      !Array.isArray(payload.items) ||
      typeof payload.page !== 'number' ||
      typeof payload.pageSize !== 'number' ||
      typeof payload.total !== 'number' ||
      payload.items.some(
        (item) =>
          !item ||
          typeof item.id !== 'string' ||
          typeof item.title !== 'string',
      )
    ) {
      throw new DependencyError(
        MATERIAL_SERVICE,
        'invalid-response',
        'Material Service devolvió un formato inesperado',
      );
    }

    return {
      items: payload.items.map((item) => this.toCandidate(item)),
      page: payload.page,
      pageSize: payload.pageSize,
      total: payload.total,
    };
  }

  private toCandidate(item: MaterialItemPayload): MaterialCandidate {
    return {
      id: item.id,
      title: item.title,
      description: item.description ?? null,
      materialType: item.materialType ?? null,
      academicYear: item.academicYear ?? null,
      verified: item.verified ?? false,
      subjectId: item.subjectId ?? null,
      careerId: item.careerId ?? null,
      universityId: item.universityId ?? null,
      professorId: item.professorId ?? null,
      createdAt: item.createdAt ?? null,
      updatedAt: item.updatedAt ?? null,
    };
  }
}
