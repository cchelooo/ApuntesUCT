import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SearchOrder, SearchQueryDto, SearchSortBy } from '../dtos/search-query.dto';
import {
  SearchResponseDto,
  SearchResultDto,
  SearchSubjectContextDto,
} from '../dtos/search-response.dto';
import { DependencyError } from '../errors/dependency.error';
import { CatalogPort, SubjectAcademicContext } from '../ports/catalog.port';
import { MaterialCandidate, MaterialPage, MaterialPort } from '../ports/material.port';

const MATERIAL_PAGE_SIZE = 100;
const MAX_MATERIAL_PAGES = 100;

@Injectable()
export class SearchService {
  constructor(
    private readonly catalog: CatalogPort,
    private readonly material: MaterialPort,
  ) {}

  async search(query: SearchQueryDto): Promise<SearchResponseDto> {
    // La regla de negocio vive en Search y se ejecuta antes de llamar a dependencias.
    this.assertHierarchy(query);
    const text = query.q?.trim() || null;
    const sortBy = query.sortBy ?? SearchSortBy.CREATED_AT;
    const order = query.order ?? SearchOrder.DESC;
    const needsScan =
      Boolean(text) ||
      this.hasAcademicFilters(query) ||
      query.year !== undefined ||
      query.type !== undefined ||
      sortBy !== SearchSortBy.CREATED_AT ||
      order !== SearchOrder.DESC;

    try {
      if (!needsScan) {
        const [academicContext, page] = await Promise.all([
          this.catalog.getAcademicContext(),
          this.material.findCandidates({ page: query.page, pageSize: query.pageSize }),
        ]);
        // Material ya ordena por createdAt DESC, id DESC; no reordenar una página aislada.
        return this.toResponse(text, page, this.contextMap(academicContext));
      }

      const [academicContext, candidates] = await Promise.all([
        this.catalog.getAcademicContext(),
        this.findAllCandidates(),
      ]);
      const contextBySubject = this.contextMap(academicContext);
      const normalizedText = text ? this.normalizeText(text) : null;
      const matches = candidates.filter((candidate) =>
        this.matches(candidate, query, normalizedText, contextBySubject),
      );
      matches.sort((a, b) => this.compareMaterials(a, b, sortBy, order));
      const start = (query.page - 1) * query.pageSize;

      return this.toResponse(
        text,
        {
          items: matches.slice(start, start + query.pageSize),
          page: query.page,
          pageSize: query.pageSize,
          total: matches.length,
        },
        contextBySubject,
      );
    } catch (error) {
      if (error instanceof HttpException) throw error;
      throw this.toHttpException(error);
    }
  }

  private assertHierarchy(query: SearchQueryDto): void {
    if (query.careerId !== undefined && query.universityId === undefined) {
      throw new BadRequestException('Secuencia inválida: careerId requiere universityId.');
    }
    if (query.subjectId !== undefined && query.careerId === undefined) {
      throw new BadRequestException(
        'Secuencia inválida: subjectId requiere careerId y universityId.',
      );
    }
    if (query.professorId !== undefined && query.subjectId === undefined) {
      throw new BadRequestException(
        'Secuencia inválida: professorId requiere subjectId, careerId y universityId.',
      );
    }
  }

  private hasAcademicFilters(query: SearchQueryDto): boolean {
    return [query.universityId, query.careerId, query.subjectId, query.professorId].some(
      (value) => value !== undefined,
    );
  }

  private contextMap(context: SubjectAcademicContext[]): Map<string, SubjectAcademicContext> {
    return new Map(context.map((subject) => [subject.subjectId.toLowerCase(), subject]));
  }

  private sameId(left: string | null | undefined, right: string | null | undefined): boolean {
    return (
      typeof left === 'string' &&
      typeof right === 'string' &&
      left.toLowerCase() === right.toLowerCase()
    );
  }

  private matches(
    candidate: MaterialCandidate,
    query: SearchQueryDto,
    text: string | null,
    contextBySubject: Map<string, SubjectAcademicContext>,
  ): boolean {
    if (
      text &&
      !this.normalizeText(candidate.title).includes(text) &&
      !this.normalizeText(candidate.description ?? '').includes(text)
    )
      return false;
    if (query.year !== undefined && candidate.academicYear !== query.year) return false;
    if (query.type !== undefined && candidate.materialType !== query.type.trim()) return false;
    if (!this.hasAcademicFilters(query)) return true;

    const context = candidate.subjectId
      ? contextBySubject.get(candidate.subjectId.toLowerCase())
      : undefined;
    if (!context) return false;
    // Catalog es la fuente de las relaciones. Nulos pueden completarse desde él;
    // valores contradictorios del material no se aceptan como coincidencias académicas.
    if (candidate.careerId !== null && !this.sameId(candidate.careerId, context.careerId))
      return false;
    if (
      candidate.universityId !== null &&
      !this.sameId(candidate.universityId, context.universityId)
    )
      return false;
    if (query.universityId !== undefined && !this.sameId(context.universityId, query.universityId))
      return false;
    if (query.careerId !== undefined && !this.sameId(context.careerId, query.careerId))
      return false;
    if (query.subjectId !== undefined && !this.sameId(candidate.subjectId, query.subjectId))
      return false;
    if (
      query.professorId !== undefined &&
      (!this.sameId(candidate.professorId, query.professorId) ||
        !context.professors.some((professor) => this.sameId(professor.id, query.professorId)))
    )
      return false;
    return true;
  }

  private sortValue(candidate: MaterialCandidate, sortBy: SearchSortBy): string | number | null {
    if (sortBy === SearchSortBy.TITLE) return this.normalizeText(candidate.title);
    if (sortBy === SearchSortBy.YEAR) return candidate.academicYear;
    if (candidate.createdAt === null) return null;
    const timestamp = Date.parse(candidate.createdAt);
    return Number.isNaN(timestamp) ? null : timestamp;
  }

  private compareMaterials(
    a: MaterialCandidate,
    b: MaterialCandidate,
    sortBy: SearchSortBy,
    order: SearchOrder,
  ): number {
    const left = this.sortValue(a, sortBy);
    const right = this.sortValue(b, sortBy);
    // Nulos al final independientemente de asc/desc.
    if (left === null && right !== null) return 1;
    if (right === null && left !== null) return -1;
    if (left !== null && right !== null && left !== right) {
      const comparison = left < right ? -1 : 1;
      return order === SearchOrder.ASC ? comparison : -comparison;
    }
    // Comparación sin locale dependiente de la máquina. Los IDs del dominio son UUID.
    const leftId = a.id.toLowerCase();
    const rightId = b.id.toLowerCase();
    return leftId < rightId ? 1 : leftId > rightId ? -1 : 0;
  }

  /** Recorrido REST completo y acotado; nunca devuelve resultados parciales. */
  private async findAllCandidates(): Promise<MaterialCandidate[]> {
    const candidates: MaterialCandidate[] = [];
    const seenIds = new Set<string>();
    let expectedTotal: number | undefined;

    for (let page = 1; page <= MAX_MATERIAL_PAGES; page += 1) {
      const result = await this.material.findCandidates({ page, pageSize: MATERIAL_PAGE_SIZE });
      this.assertValidMaterialPage(result, page, expectedTotal);
      if (expectedTotal === undefined) {
        expectedTotal = result.total;
        if (Math.ceil(expectedTotal / MATERIAL_PAGE_SIZE) > MAX_MATERIAL_PAGES) {
          throw new ServiceUnavailableException(
            'La búsqueda supera el límite de materiales que puede procesarse.',
          );
        }
      }
      for (const candidate of result.items) {
        const id = candidate.id.toLowerCase();
        if (seenIds.has(id)) {
          throw new BadGatewayException(
            'Material Service devolvió materiales duplicados durante la búsqueda.',
          );
        }
        seenIds.add(id);
        candidates.push(candidate);
      }
      if (seenIds.size === expectedTotal) return candidates;
    }
    throw new ServiceUnavailableException('No fue posible completar la búsqueda de materiales.');
  }

  private assertValidMaterialPage(
    materialPage: MaterialPage,
    requestedPage: number,
    expectedTotal?: number,
  ): void {
    if (
      materialPage.page !== requestedPage ||
      materialPage.pageSize !== MATERIAL_PAGE_SIZE ||
      !Number.isSafeInteger(materialPage.total) ||
      materialPage.total < 0 ||
      !Array.isArray(materialPage.items)
    ) {
      throw new BadGatewayException('Material Service devolvió una paginación inválida.');
    }
    if (expectedTotal !== undefined && materialPage.total !== expectedTotal) {
      throw new BadGatewayException(
        'El listado de Material cambió durante la búsqueda. Intenta nuevamente.',
      );
    }
    const offset = (requestedPage - 1) * MATERIAL_PAGE_SIZE;
    const expectedItems = Math.max(0, Math.min(MATERIAL_PAGE_SIZE, materialPage.total - offset));
    if (materialPage.items.length !== expectedItems) {
      throw new BadGatewayException(
        'Material Service devolvió una página incompleta durante la búsqueda.',
      );
    }
  }

  private normalizeText(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  private toResponse(
    text: string | null,
    page: MaterialPage,
    contextBySubject: Map<string, SubjectAcademicContext>,
  ): SearchResponseDto {
    return {
      query: text,
      page: page.page,
      pageSize: page.pageSize,
      total: page.total,
      results: page.items.map((material) => this.toResult(material, contextBySubject)),
      context: this.toContextList(page.items, contextBySubject),
    };
  }

  private toResult(
    material: MaterialCandidate,
    contextBySubject: Map<string, SubjectAcademicContext>,
  ): SearchResultDto {
    const context = material.subjectId
      ? contextBySubject.get(material.subjectId.toLowerCase())
      : undefined;
    return {
      id: material.id,
      title: material.title,
      description: material.description,
      materialType: material.materialType,
      academicYear: material.academicYear,
      verified: material.verified,
      subjectId: material.subjectId,
      careerId: material.careerId ?? context?.careerId ?? null,
      universityId: material.universityId ?? context?.universityId ?? null,
      professorId: material.professorId,
      subjectName: context?.subjectName ?? null,
      careerName: context?.careerName ?? null,
      universityName: context?.universityName ?? null,
      createdAt: material.createdAt,
      updatedAt: material.updatedAt,
    };
  }

  private toContextList(
    materials: MaterialCandidate[],
    contextBySubject: Map<string, SubjectAcademicContext>,
  ): SearchSubjectContextDto[] {
    const seen = new Set<string>();
    const context: SearchSubjectContextDto[] = [];
    for (const material of materials) {
      if (!material.subjectId) continue;
      const id = material.subjectId.toLowerCase();
      if (seen.has(id)) continue;
      seen.add(id);
      const subject = contextBySubject.get(id);
      if (!subject) continue;
      context.push({
        subjectId: subject.subjectId,
        subjectName: subject.subjectName,
        subjectCode: subject.subjectCode,
        semester: subject.semester,
        careerId: subject.careerId,
        careerName: subject.careerName,
        universityId: subject.universityId,
        universityName: subject.universityName,
        professors: subject.professors,
      });
    }
    return context;
  }

  private toHttpException(error: unknown): HttpException {
    if (!(error instanceof DependencyError))
      return new ServiceUnavailableException('Un servicio dependiente no está disponible');
    if (error.failure === 'invalid-response') return new BadGatewayException(error.message);
    if (error.failure === 'upstream-error') {
      if (error.status === 400 || error.status === 422) {
        return new BadRequestException(
          `La solicitud de búsqueda no es válida para ${error.service}`,
        );
      }
      if (error.status !== undefined && error.status >= 400 && error.status < 500)
        return new BadGatewayException(error.message);
    }
    return new ServiceUnavailableException(error.message);
  }
}
