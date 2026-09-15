import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async filterCatalog(filters: FilterCatalogDto) {
    const { universityId, careerId, subjectId, professorId, year, type } = filters;

    // Validación de secuencia jerárquica estricta
    if (careerId && !universityId) {
      throw new BadRequestException('universityId es requerido para filtrar por carrera.');
    }
    if (subjectId && !careerId) {
      throw new BadRequestException('careerId es requerido para filtrar por asignatura.');
    }
    if (professorId && !subjectId) {
      throw new BadRequestException('subjectId es requerido para filtrar por profesor.');
    }
    if (year && !professorId) {
      throw new BadRequestException('professorId es requerido para filtrar por año.');
    }
    if (type && !year) {
      throw new BadRequestException('year es requerido para filtrar por tipo.');
    }

    // Construcción de consulta en Prisma con dependencias encadenadas
    return this.prisma.subject.findMany({
      where: {
        ...(subjectId ? { id: subjectId } : {}),
        ...(careerId ? { careerId } : {}),
        ...(universityId ? { career: { universityId } } : {}),
        ...(professorId ? { professors: { some: { id: professorId } } } : {}),
        // Aplicar filtros adicionales de año y tipo según la relación con el recurso final
      },
      include: {
        career: {
          include: {
            university: true,
          },
        },
        professors: true,
      },
    });
  }
}