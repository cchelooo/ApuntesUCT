import { Injectable } from '@nestjs/common';
import { DependencyError } from '../../application/errors/dependency.error';
import {
  CatalogPort,
  SubjectAcademicContext,
} from '../../application/ports/catalog.port';
import { getJson } from './http-client';
import { isInteger, isNonEmptyString, isRecord } from './payload-validators';

const CATALOG_SERVICE = 'Catalog Service';

function invalidResponse(message: string, cause?: unknown): DependencyError {
  return new DependencyError(CATALOG_SERVICE, 'invalid-response', message, {
    cause,
  });
}

function isProfessor(value: unknown): value is { id: string; name: string } {
  return (
    isRecord(value) &&
    isNonEmptyString(value.id) &&
    isNonEmptyString(value.name)
  );
}

@Injectable()
export class CatalogHttpAdapter extends CatalogPort {
  private readonly baseUrl =
    process.env.CATALOG_SERVICE_URL ?? 'http://127.0.0.1:3002';

  async getAcademicContext(): Promise<SubjectAcademicContext[]> {
    const url = new URL('/api/v1/catalog/filter', this.baseUrl);
    const payload = await getJson<unknown>(url.toString(), CATALOG_SERVICE);

    if (!Array.isArray(payload)) {
      throw invalidResponse(
        'Catalog Service devolvió un formato inesperado para el catálogo',
      );
    }

    try {
      return payload.map((subject) => this.toAcademicContext(subject));
    } catch (error) {
      if (error instanceof DependencyError) {
        throw error;
      }

      throw invalidResponse(
        'Catalog Service devolvió un formato inesperado para el catálogo',
        error,
      );
    }
  }

  private toAcademicContext(subject: unknown): SubjectAcademicContext {
    if (
      !isRecord(subject) ||
      !isNonEmptyString(subject.id) ||
      !isNonEmptyString(subject.name) ||
      !isNonEmptyString(subject.code) ||
      !isInteger(subject.semester)
    ) {
      throw invalidResponse(
        'Catalog Service devolvió una asignatura con campos inválidos',
      );
    }

    const career = subject.career;
    if (
      !isRecord(career) ||
      !isNonEmptyString(career.id) ||
      !isNonEmptyString(career.name)
    ) {
      throw invalidResponse(
        'Catalog Service devolvió una carrera con campos inválidos',
      );
    }

    const university = career.university;
    if (
      !isRecord(university) ||
      !isNonEmptyString(university.id) ||
      !isNonEmptyString(university.name)
    ) {
      throw invalidResponse(
        'Catalog Service devolvió una universidad con campos inválidos',
      );
    }

    const professors = subject.professors;
    if (!Array.isArray(professors) || !professors.every(isProfessor)) {
      throw invalidResponse(
        'Catalog Service devolvió profesores con campos inválidos',
      );
    }

    return {
      subjectId: subject.id,
      subjectName: subject.name,
      subjectCode: subject.code,
      semester: subject.semester,
      careerId: career.id,
      careerName: career.name,
      universityId: university.id,
      universityName: university.name,
      professors: professors.map((professor) => ({
        id: professor.id,
        name: professor.name,
      })),
    };
  }
}
