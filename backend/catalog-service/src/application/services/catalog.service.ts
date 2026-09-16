import {
  BadRequestException,
  Injectable,
  NotImplementedException,
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async filterCatalog(filters: FilterCatalogDto) {
    // 1. Validaciones de la secuencia jerárquica (los 6 niveles)
    if (filters.careerId && !filters.universityId) {
      throw new BadRequestException(
        'Secuencia inválida: Para filtrar por Carrera (careerId) debe especificar Universidad (universityId).',
      );
    }

    if (filters.subjectId && !filters.careerId) {
      throw new BadRequestException(
        'Secuencia inválida: Para filtrar por Asignatura (subjectId) debe especificar Carrera (careerId).',
      );
    }

    if (filters.professorId && !filters.subjectId) {
      throw new BadRequestException(
        'Secuencia inválida: Para filtrar por Profesor (professorId) debe especificar Asignatura (subjectId).',
      );
    }

    if (filters.year && !filters.professorId) {
      throw new BadRequestException(
        'Secuencia inválida: Para filtrar por Año (year) debe especificar Profesor (professorId).',
      );
    }

    if (filters.type && !filters.year) {
      throw new BadRequestException(
        'Secuencia inválida: Para filtrar por Tipo (type) debe especificar Año (year).',
      );
    }

    // 2. Documentar la dependencia pendiente para los niveles 5 y 6 (Año y Tipo)
    // NOTA: Los filtros 'year' y 'type' pertenecen al recurso (Resource).
    // Hasta que el modelo Resource esté integrado en Prisma, informamos al cliente.
    if (filters.year || filters.type) {
      throw new NotImplementedException(
        'Los filtros por Año y Tipo requieren el módulo de Recursos (Resource), el cual está pendiente de integración en la base de datos.',
      );
    }

    // 3. Consulta en BD para niveles 1 al 4 (Universidad, Carrera, Asignatura, Profesor)
    const whereCondition: Record<string, unknown> = {};

    if (filters.universityId) {
      whereCondition.career = { universityId: filters.universityId };
    }

    if (filters.careerId) {
      whereCondition.careerId = filters.careerId;
    }

    if (filters.subjectId) {
      whereCondition.id = filters.subjectId;
    }

    if (filters.professorId) {
      whereCondition.professors = {
        some: { id: filters.professorId },
      };
    }

    return this.prisma.subject.findMany({
      where: whereCondition,
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
