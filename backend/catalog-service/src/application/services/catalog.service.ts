import {
  BadRequestException,
  Injectable,
  NotImplementedException,
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';
import { UniversityResponseDto } from '../dtos/catalog-response.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Obtiene la estructura completa del catálogo en forma de árbol
   * (Universidad -> Carrera -> Asignatura)
   */
  async getCatalogTree(): Promise<UniversityResponseDto[]> {
    return this.prisma.university.findMany({
      where: { active: true },
      select: {
        id: true,
        name: true,
        code: true,
        active: true,
        createdAt: true,
        updatedAt: true,
        careers: {
          where: { active: true },
          select: {
            id: true,
            name: true,
            code: true,
            active: true,
            createdAt: true,
            updatedAt: true,
            subjects: {
              select: {
                id: true,
                name: true,
                code: true,
                semester: true, // <-- Incluido para cumplir la firma de SubjectResponseDto
                active: true,
                createdAt: true,
                updatedAt: true
              },
            },
          },
        },
      },
    });
  }

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
    if (filters.year || filters.type) {
      throw new NotImplementedException(
        'Los filtros por Año y Tipo requieren el módulo de Recursos (Resource), el cual está pendiente de integración en la base de datos.',
      );
    }

    // 3. Consulta en BD para niveles 1 al 4 utilizando tipos estrictos de Prisma
    const whereCondition: Prisma.SubjectWhereInput = {};

    if (filters.universityId) {
      whereCondition.career = {
        universityId: filters.universityId,
      };
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
