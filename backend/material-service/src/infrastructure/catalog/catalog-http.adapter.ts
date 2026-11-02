import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import {
  AcademicReferences,
  CatalogPort,
  CatalogUnavailableError,
  InvalidAcademicReferenceError,
} from '../../application/ports/catalog.port';

interface CatalogSubject {
  id: string;
  active: boolean;
}
interface CatalogCareer {
  id: string;
  active: boolean;
  subjects: CatalogSubject[];
}
interface CatalogUniversity {
  id: string;
  active: boolean;
  careers: CatalogCareer[];
}
interface CatalogProfessor {
  id: string;
  active: boolean;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isEntity(value: unknown): value is Record<string, unknown> & CatalogSubject {
  return (
    isRecord(value) &&
    typeof value.id === 'string' &&
    isUUID(value.id) &&
    typeof value.active === 'boolean'
  );
}

function isTree(value: unknown): value is CatalogUniversity[] {
  return (
    Array.isArray(value) &&
    value.every(
      (university: unknown) =>
        isEntity(university) &&
        Array.isArray(university.careers) &&
        university.careers.every(
          (career: unknown) =>
            isEntity(career) &&
            Array.isArray(career.subjects) &&
            career.subjects.every((subject: unknown) => isEntity(subject)),
        ),
    )
  );
}

function isProfessors(value: unknown): value is CatalogProfessor[] {
  return Array.isArray(value) && value.every((professor: unknown) => isEntity(professor));
}

@Injectable()
export class CatalogHttpAdapter extends CatalogPort {
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(config: ConfigService) {
    super();
    const configuredUrl =
      config.get<string>('catalog.baseUrl') ??
      config.get<string>('CATALOG_SERVICE_URL') ??
      'http://localhost:3002/api/v1';
    const url = new URL(configuredUrl);
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.search ||
      url.hash
    ) {
      throw new Error(
        'CATALOG_SERVICE_URL debe ser una URL HTTP(S) sin credenciales, query ni fragmento.',
      );
    }
    this.baseUrl = url.toString().replace(/\/+$/, '');
    this.timeoutMs = Number(
      config.get<number | string>('catalog.timeoutMs') ??
        config.get<string>('CATALOG_TIMEOUT_MS') ??
        5000,
    );
    if (!Number.isSafeInteger(this.timeoutMs) || this.timeoutMs <= 0) {
      throw new Error('CATALOG_TIMEOUT_MS debe ser un entero positivo.');
    }
  }

  async validateReferences(references: AcademicReferences): Promise<void> {
    for (const field of ['subjectId', 'careerId', 'professorId', 'universityId'] as const) {
      const value = references[field];
      if (field !== 'subjectId' && (value === undefined || value === null)) continue;
      if (typeof value !== 'string' || !isUUID(value)) {
        throw new InvalidAcademicReferenceError(
          field,
          `${field} debe ser un UUID válido de Catalog.`,
        );
      }
    }

    const tree: unknown = await this.requestJson('/catalog');
    if (!isTree(tree)) throw new CatalogUnavailableError();
    let match: { university: CatalogUniversity; career: CatalogCareer } | undefined;
    for (const university of tree) {
      if (!university.active) continue;
      for (const career of university.careers) {
        if (!career.active) continue;
        for (const subject of career.subjects) {
          if (subject.active && subject.id === references.subjectId) {
            if (match) throw new CatalogUnavailableError();
            match = { university, career };
          }
        }
      }
    }
    if (!match) {
      throw new InvalidAcademicReferenceError(
        'subjectId',
        'La asignatura no existe o su jerarquía académica no está activa.',
      );
    }
    if (references.careerId !== undefined && references.careerId !== match.career.id) {
      throw new InvalidAcademicReferenceError(
        'careerId',
        'La asignatura no pertenece a la carrera indicada.',
      );
    }
    if (references.universityId !== null && references.universityId !== match.university.id) {
      throw new InvalidAcademicReferenceError(
        'universityId',
        'La asignatura no pertenece a la universidad del contexto de autor.',
      );
    }
    if (references.professorId !== undefined) {
      const params = new URLSearchParams({ subjectId: references.subjectId });
      const professors: unknown = await this.requestJson(
        `/catalog/professors?${params.toString()}`,
      );
      if (!isProfessors(professors)) throw new CatalogUnavailableError();
      if (
        !professors.some((professor) => professor.active && professor.id === references.professorId)
      ) {
        throw new InvalidAcademicReferenceError(
          'professorId',
          'El profesor no está activo o no está vinculado a la asignatura.',
        );
      }
    }
  }

  private async requestJson(path: string): Promise<unknown> {
    try {
      const response = await fetch(`${this.baseUrl}${path}`, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(this.timeoutMs),
        redirect: 'error',
      });
      if (!response.ok) throw new CatalogUnavailableError();
      const body: unknown = await response.json();
      return body;
    } catch {
      // No publicar URLs internas, errores de red ni respuestas del servicio remoto.
      throw new CatalogUnavailableError();
    }
  }
}
