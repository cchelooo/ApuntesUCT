import { Injectable } from '@nestjs/common';
import { DependencyError } from '../../application/errors/dependency.error';
import {
  CatalogPort,
  SubjectAcademicContext,
} from '../../application/ports/catalog.port';
import { getJson } from './http-client';

const CATALOG_SERVICE = 'Catalog Service';

interface CatalogSubjectPayload {
  id: string;
  name: string;
  code?: string | null;
  semester?: number | null;
  careerId?: string | null;
  career?: {
    id?: string;
    name?: string;
    universityId?: string | null;
    university?: { id?: string; name?: string } | null;
  } | null;
  professors?: Array<{ id: string; name: string }> | null;
}

@Injectable()
export class CatalogHttpAdapter extends CatalogPort {
  private readonly baseUrl =
    process.env.CATALOG_SERVICE_URL ?? 'http://127.0.0.1:3002';

  async getAcademicContext(): Promise<SubjectAcademicContext[]> {
    const url = new URL('/api/v1/catalog/filter', this.baseUrl);
    const payload = await getJson<CatalogSubjectPayload[]>(
      url.toString(),
      CATALOG_SERVICE,
    );

    if (
      !Array.isArray(payload) ||
      payload.some(
        (subject) =>
          !subject ||
          typeof subject.id !== 'string' ||
          typeof subject.name !== 'string',
      )
    ) {
      throw new DependencyError(
        CATALOG_SERVICE,
        'invalid-response',
        'Catalog Service devolvió un formato inesperado',
      );
    }

    return payload.map((subject) => this.toAcademicContext(subject));
  }

  private toAcademicContext(
    subject: CatalogSubjectPayload,
  ): SubjectAcademicContext {
    return {
      subjectId: subject.id,
      subjectName: subject.name,
      subjectCode: subject.code ?? null,
      semester: subject.semester ?? null,
      careerId: subject.career?.id ?? subject.careerId ?? null,
      careerName: subject.career?.name ?? null,
      universityId:
        subject.career?.university?.id ??
        subject.career?.universityId ??
        null,
      universityName: subject.career?.university?.name ?? null,
      professors: (subject.professors ?? []).map((professor) => ({
        id: professor.id,
        name: professor.name,
      })),
    };
  }
}
