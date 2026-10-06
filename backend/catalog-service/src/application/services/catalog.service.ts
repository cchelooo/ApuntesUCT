import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';
import { UniversityResponseDto } from '../dtos/catalog-response.dto';
import { Prisma } from '@prisma/client';
import { CreateSubjectDto } from '../dtos/create-subject.dto';
import { CreateUniversityDto } from '../dtos/create-university.dto';
import { CreateCareerDto } from '../dtos/create-career.dto';
import { CreateProfessorDto } from '../dtos/create-professor.dto';

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
    // Catalog solo modela la jerarquía hasta Profesor. Los metadatos de los
    // materiales (año, tipo) pertenecen a Material Service y la búsqueda por
    // año/tipo corresponde a Search Service: aquí no se consultan.
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
  // LISTADOS PARA LOS SELECTORES ACADÉMICOS
  //
  // Cada listado devuelve solo entidades activas y permite filtrar por su
  // padre inmediato, que es lo que consumen los selectores en cascada del
  // frontend (universidad -> carrera -> asignatura -> profesor).
  // =========================================================================

  listUniversities() {
    return this.prisma.university.findMany({
      where: { active: true },
      orderBy: { name: 'asc' },
    });
  }

  listCareers(universityId?: string) {
    return this.prisma.career.findMany({
      where: {
        active: true,
        ...(universityId ? { universityId } : {}),
      },
      orderBy: { name: 'asc' },
    });
  }

  listSubjects(careerId?: string) {
    return this.prisma.subject.findMany({
      where: {
        active: true,
        ...(careerId ? { careerId } : {}),
      },
      orderBy: { name: 'asc' },
    });
  }

  listProfessors(subjectId?: string) {
    return this.prisma.professor.findMany({
      where: {
        active: true,
        ...(subjectId ? { subjects: { some: { id: subjectId } } } : {}),
      },
      orderBy: { name: 'asc' },
    });
  }

  // =========================================================================
  // GESTIÓN DEL CATÁLOGO (Creación y Eliminación)
  //
  // Cada entidad valida que su padre exista antes de crearse y traduce la
  // violación de clave única de Prisma (P2002) a un 409 legible.
  // =========================================================================

  /** Traduce una violación de clave única (P2002) a un 409 con mensaje propio. */
  private rethrowIfDuplicated(error: unknown, message: string): never | void {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      throw new ConflictException(message);
    }
    throw error;
  }

  /** Lanza 404 si la entidad no existe, evitando que Prisma devuelva otro error. */
  private async assertExists(
    find: () => Promise<unknown>,
    message: string,
  ): Promise<void> {
    const found = await find();
    if (!found) {
      throw new NotFoundException(message);
    }
  }

  async createUniversity(data: CreateUniversityDto) {
    try {
      return await this.prisma.university.create({
        data: {
          name: data.name,
          code: data.code,
          active: data.active ?? true,
        },
      });
    } catch (error) {
      this.rethrowIfDuplicated(
        error,
        `Ya existe una universidad con el código '${data.code}'.`,
      );
    }
  }

  async deleteUniversity(id: string) {
    await this.assertExists(
      () => this.prisma.university.findUnique({ where: { id } }),
      `La universidad con ID ${id} no existe.`,
    );
    return this.prisma.university.delete({ where: { id } });
  }

  async createCareer(data: CreateCareerDto) {
    await this.assertExists(
      () => this.prisma.university.findUnique({ where: { id: data.universityId } }),
      `La universidad con ID ${data.universityId} no existe.`,
    );

    try {
      return await this.prisma.career.create({
        data: {
          name: data.name,
          code: data.code,
          universityId: data.universityId,
          active: data.active ?? true,
        },
      });
    } catch (error) {
      this.rethrowIfDuplicated(
        error,
        `Ya existe una carrera con el código '${data.code}' registrada en esta universidad.`,
      );
    }
  }

  async deleteCareer(id: string) {
    await this.assertExists(
      () => this.prisma.career.findUnique({ where: { id } }),
      `La carrera con ID ${id} no existe.`,
    );
    return this.prisma.career.delete({ where: { id } });
  }

  async createProfessor(data: CreateProfessorDto) {
    const subjectIds = data.subjectIds ?? [];

    // Todas las asignaturas deben existir antes de vincular, para no dejar
    // vínculos parciales si alguna no se encuentra.
    if (subjectIds.length > 0) {
      const found = await this.prisma.subject.findMany({
        where: { id: { in: subjectIds } },
        select: { id: true },
      });

      const foundIds = new Set(found.map((subject) => subject.id));
      const missing = subjectIds.filter((id) => !foundIds.has(id));

      if (missing.length > 0) {
        throw new NotFoundException(
          `La(s) asignatura(s) con ID ${missing.join(', ')} no existen.`,
        );
      }
    }

    try {
      return await this.prisma.professor.create({
        data: {
          name: data.name,
          email: data.email,
          active: data.active ?? true,
          subjects: {
            connect: subjectIds.map((id) => ({ id })),
          },
        },
        include: { subjects: true },
      });
    } catch (error) {
      this.rethrowIfDuplicated(
        error,
        `Ya existe un profesor registrado con el correo '${data.email}'.`,
      );
    }
  }

  async deleteProfessor(id: string) {
    await this.assertExists(
      () => this.prisma.professor.findUnique({ where: { id } }),
      `El profesor con ID ${id} no existe.`,
    );
    return this.prisma.professor.delete({ where: { id } });
  }

  async createSubject(data: CreateSubjectDto) {
    // Verificar que la carrera especificada exista
    await this.assertExists(
      () => this.prisma.career.findUnique({ where: { id: data.careerId } }),
      `La carrera con ID ${data.careerId} no existe.`,
    );

    try {
      // Intentar crear la asignatura vinculada a la carrera
      return await this.prisma.subject.create({
        data: {
          name: data.name,
          code: data.code,
          semester: data.semester,
          careerId: data.careerId,
          description: data.description,
          active: data.active ?? true,
        },
      });
    } catch (error) {
      // Error P2002: Violación de restricción de clave única (career_id, code)
      this.rethrowIfDuplicated(
        error,
        `Ya existe una asignatura con el código '${data.code}' registrada en esta carrera.`,
      );
    }
  }

  async deleteSubject(id: string) {
    await this.assertExists(
      () => this.prisma.subject.findUnique({ where: { id } }),
      `La asignatura con ID ${id} no existe.`,
    );

    return this.prisma.subject.delete({
      where: { id },
    });
  }
}