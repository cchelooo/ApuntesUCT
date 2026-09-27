import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotImplementedException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';
import { UniversityResponseDto } from '../dtos/catalog-response.dto';
import { Prisma } from '@prisma/client';
import { CreateSubjectDto } from '../dtos/create-subject.dto';

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
                semester: true,
                active: true,
                createdAt: true,
                updatedAt: true,
              },
            },
          },
        },
      },
    });
  }

  async filterCatalog(filters: FilterCatalogDto) {
    // 1. PRIORIDAD MÁXIMA: Si se solicita 'year' o 'type', retorna 501 Not Implemented de inmediato.
    if (filters.year !== undefined || filters.type !== undefined) {
      throw new NotImplementedException(
        'Los filtros por Año y Tipo requieren el módulo de Recursos (Resource), el cual está pendiente de integración en la base de datos.',
      );
    }

    // 2. Validaciones de la secuencia jerárquica (Niveles 1 al 4)
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

  // =========================================================================
  // GESTIÓN DE ASIGNATURAS (Creación y Eliminación)
  // =========================================================================

  async createSubject(data: CreateSubjectDto) {
    // Verificar que la carrera especificada exista
    const career = await this.prisma.career.findUnique({
      where: { id: data.careerId },
    });

    if (!career) {
      throw new NotFoundException(
        `La carrera con ID ${data.careerId} no existe.`,
      );
    }

    try {
      // Intentar crear la asignatura vinculada a la carrera
      return await this.prisma.subject.create({
        data: {
          name: data.name,
          code: data.code,
          semester: data.semester,
          careerId: data.careerId,
        },
      });
    } catch (error) {
      // Error P2002: Violación de restricción de clave única (career_id, code)
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException(
          `Ya existe una asignatura con el código '${data.code}' registrada en esta carrera.`,
        );
      }
      throw error;
    }
  }

  async deleteSubject(id: string) {
    const subject = await this.prisma.subject.findUnique({
      where: { id },
    });

    if (!subject) {
      throw new NotFoundException(
        `La asignatura con ID ${id} no existe.`,
      );
    }

    return this.prisma.subject.delete({
      where: { id },
    });
  }
}