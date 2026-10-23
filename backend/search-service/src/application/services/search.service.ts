import {
  BadGatewayException,
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

@Injectable()
export class SearchService {
  constructor(
    private readonly catalog: CatalogPort,
    private readonly material: MaterialPort,
  ) {}

  async search(query: SearchQueryDto): Promise<SearchResponseDto> {
    let academicContext: SubjectAcademicContext[];
    let materials: MaterialPage;

    try {
      [academicContext, materials] = await Promise.all([
        this.catalog.getAcademicContext(),
        this.material.findCandidates({
          page: query.page,
          pageSize: query.pageSize,
        }),
      ]);
    } catch (error) {
      throw this.toHttpException(error);
    }

    const contextBySubject = new Map(
      academicContext.map((subject) => [subject.subjectId, subject]),
    );

    return {
      query: query.q ?? null,
      page: materials.page,
      pageSize: materials.pageSize,
      total: materials.total,
      results: materials.items.map((material) =>
        this.toResult(material, contextBySubject),
      ),
      context: this.toContextList(materials.items, contextBySubject),
    };
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
    if (error instanceof DependencyError) {
      return error.failure === 'invalid-response'
        ? new BadGatewayException(error.message)
        : new ServiceUnavailableException(error.message);
    }

    return new ServiceUnavailableException(
      'Un servicio dependiente no está disponible',
    );
  }
}
