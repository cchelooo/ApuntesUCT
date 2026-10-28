import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SearchQueryDto } from '../dtos/search-query.dto';
import {
  SearchResponseDto,
  SearchResultDto,
  SearchSubjectContextDto,
} from '../dtos/search-response.dto';
import { DependencyError } from '../errors/dependency.error';
import { CatalogPort, SubjectAcademicContext } from '../ports/catalog.port';
import {
  MaterialCandidate,
  MaterialPage,
  MaterialPort,
} from '../ports/material.port';

/**
 * Material permite solicitar como máximo 100 elementos por página.
 *
 * El límite de páginas evita recorrer una cantidad ilimitada de materiales
 * durante una búsqueda textual. Si se supera, se devuelve un error controlado:
 * no se entregan resultados incompletos como si fueran definitivos.
 */
const MATERIAL_PAGE_SIZE = 100;
const MAX_MATERIAL_PAGES = 100;

@Injectable()
export class SearchService {
  constructor(
    private readonly catalog: CatalogPort,
    private readonly material: MaterialPort,
  ) {}

  async search(query: SearchQueryDto): Promise<SearchResponseDto> {
    const text = query.q?.trim() || null;

    let academicContext: SubjectAcademicContext[];
    let materials: MaterialPage;

    try {
      [academicContext, materials] = await Promise.all([
        this.catalog.getAcademicContext(),
        text
          ? this.searchMaterialsByText(text, query.page, query.pageSize)
          : this.material.findCandidates({
              page: query.page,
              pageSize: query.pageSize,
            }),
      ]);
    } catch (error) {
      // Los errores de validación o límites generados por Search conservan
      // su respuesta. Los errores de dependencias se traducen como antes.
      if (error instanceof HttpException) {
        throw error;
      }

      throw this.toHttpException(error);
    }

    const contextBySubject = new Map(
      academicContext.map((subject) => [subject.subjectId, subject]),
    );

    return {
      query: text,
      page: materials.page,
      pageSize: materials.pageSize,
      total: materials.total,
      results: materials.items.map((material) =>
        this.toResult(material, contextBySubject),
      ),
      context: this.toContextList(materials.items, contextBySubject),
    };
  }

  /**
   * Busca en todas las páginas de candidatos antes de aplicar la
   * paginación solicitada por el usuario.
   */
  private async searchMaterialsByText(
    text: string,
    page: number,
    pageSize: number,
  ): Promise<MaterialPage> {
    const normalizedText = this.normalizeText(text);
    const matches: MaterialCandidate[] = [];
    const seenIds = new Set<string>();

    let expectedTotal: number | undefined;

    for (
      let materialPageNumber = 1;
      materialPageNumber <= MAX_MATERIAL_PAGES;
      materialPageNumber += 1
    ) {
      const materialPage = await this.material.findCandidates({
        page: materialPageNumber,
        pageSize: MATERIAL_PAGE_SIZE,
      });

      this.assertValidMaterialPage(
        materialPage,
        materialPageNumber,
        expectedTotal,
      );

      if (expectedTotal === undefined) {
        expectedTotal = materialPage.total;

        const requiredPages = Math.ceil(
          expectedTotal / MATERIAL_PAGE_SIZE,
        );

        if (requiredPages > MAX_MATERIAL_PAGES) {
          throw new ServiceUnavailableException(
            'La búsqueda supera el límite de materiales que puede procesarse.',
          );
        }
      }

      for (const candidate of materialPage.items) {
        if (seenIds.has(candidate.id)) {
          throw new BadGatewayException(
            'Material Service devolvió materiales duplicados durante la búsqueda.',
          );
        }

        seenIds.add(candidate.id);

        const titleMatches = this.normalizeText(candidate.title).includes(
          normalizedText,
        );

        const descriptionMatches =
          candidate.description !== null &&
          this.normalizeText(candidate.description).includes(normalizedText);

        if (titleMatches || descriptionMatches) {
          matches.push(candidate);
        }
      }

      if (seenIds.size === expectedTotal) {
        const start = (page - 1) * pageSize;

        return {
          items: matches.slice(start, start + pageSize),
          page,
          pageSize,
          total: matches.length,
        };
      }
    }

    throw new ServiceUnavailableException(
      'No fue posible completar la búsqueda de materiales.',
    );
  }

  /**
   * Comprueba la coherencia de cada página recibida.
   *
   * Estas comprobaciones detectan algunos cambios concurrentes, aunque el
   * contrato paginado de Material no garantiza una instantánea compartida
   * entre solicitudes.
   */
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
      throw new BadGatewayException(
        'Material Service devolvió una paginación inválida.',
      );
    }

    if (
      expectedTotal !== undefined &&
      materialPage.total !== expectedTotal
    ) {
      throw new BadGatewayException(
        'El listado de Material cambió durante la búsqueda. Intenta nuevamente.',
      );
    }

    const offset = (requestedPage - 1) * MATERIAL_PAGE_SIZE;
    const expectedItems = Math.max(
      0,
      Math.min(MATERIAL_PAGE_SIZE, materialPage.total - offset),
    );

    if (materialPage.items.length !== expectedItems) {
      throw new BadGatewayException(
        'Material Service devolvió una página incompleta durante la búsqueda.',
      );
    }
  }

  /**
   * Permite que "algebra" coincida con "Álgebra" y evita diferencias
   * entre mayúsculas y minúsculas.
   */
  private normalizeText(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  private toResult(
    material: MaterialCandidate,
    contextBySubject: Map<string, SubjectAcademicContext>,
  ): SearchResultDto {
    const context = material.subjectId
      ? contextBySubject.get(material.subjectId)
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
      if (!material.subjectId || seen.has(material.subjectId)) {
        continue;
      }

      seen.add(material.subjectId);
      const subject = contextBySubject.get(material.subjectId);

      if (!subject) {
        continue;
      }

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
    if (!(error instanceof DependencyError)) {
      return new ServiceUnavailableException(
        'Un servicio dependiente no está disponible',
      );
    }

    if (error.failure === 'invalid-response') {
      return new BadGatewayException(error.message);
    }

    if (error.failure === 'upstream-error') {
      if (error.status === 400 || error.status === 422) {
        return new BadRequestException(
          `La solicitud de búsqueda no es válida para ${error.service}`,
        );
      }

      if (
        error.status !== undefined &&
        error.status >= 400 &&
        error.status < 500
      ) {
        return new BadGatewayException(error.message);
      }
    }

    return new ServiceUnavailableException(error.message);
  }
}