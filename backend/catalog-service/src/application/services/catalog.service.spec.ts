import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma, ResourceType } from '@prisma/client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';
import { CatalogService } from './catalog.service';

describe('CatalogService', () => {
  let service: CatalogService;
  let prismaService: jest.Mocked<PrismaService>;

  const mockPrismaService = {
    subject: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
    },
    university: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
    },
    career: {
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
    },
    professor: {
      create: jest.fn(),
      findUnique: jest.fn(),
      delete: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<CatalogService>(CatalogService);
    prismaService = module.get(PrismaService);

    jest.clearAllMocks();
  });

  it('debe estar definido', () => {
    expect(service).toBeDefined();
  });

  describe('getCatalogTree', () => {
    it('debe consultar la BD y retornar la estructura en árbol de universidades activas', async () => {
      const mockResult = [
        {
          id: 'univ-123',
          name: 'Universidad Católica de Temuco',
          code: 'UCT',
          active: true,
          createdAt: new Date(),
          updatedAt: new Date(),
          careers: [
            {
              id: 'career-123',
              name: 'Ingeniería Civil en Informática',
              code: 'ICI',
              active: true,
              createdAt: new Date(),
              updatedAt: new Date(),
              subjects: [
                {
                  id: 'subj-123',
                  name: 'Estructura de Datos',
                  code: 'ICI-201',
                  semester: 3,
                  active: true,
                  createdAt: new Date(),
                  updatedAt: new Date(),
                },
              ],
            },
          ],
        },
      ] as unknown as ReturnType<CatalogService['getCatalogTree']>;

      mockPrismaService.university.findMany.mockResolvedValue(mockResult);

      const result = await service.getCatalogTree();

      expect(prismaService.university.findMany).toHaveBeenCalledWith({
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
      expect(result).toEqual(mockResult);
    });
  });

  describe('filterCatalog - Validaciones de la secuencia jerárquica (6 Niveles)', () => {
    it('debe lanzar BadRequestException si se especifica careerId sin universityId', async () => {
      const filters: FilterCatalogDto = { careerId: 'career-123' };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Secuencia inválida: Para filtrar por Carrera (careerId) debe especificar Universidad (universityId).',
      );
    });

    it('debe lanzar BadRequestException si se especifica subjectId sin careerId', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        subjectId: 'subj-123',
      };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Secuencia inválida: Para filtrar por Asignatura (subjectId) debe especificar Carrera (careerId).',
      );
    });

    it('debe lanzar BadRequestException si se especifica professorId sin subjectId', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        professorId: 'prof-123',
      };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Secuencia inválida: Para filtrar por Profesor (professorId) debe especificar Asignatura (subjectId).',
      );
    });

    it('debe lanzar BadRequestException si se especifica year sin professorId', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        year: 2026,
      };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Secuencia inválida: Para filtrar por Año (year) debe especificar Profesor (professorId).',
      );
    });

    it('debe lanzar BadRequestException si se especifica type sin year', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
        type: 'Examen',
      };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        BadRequestException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Secuencia inválida: Para filtrar por Tipo (type) debe especificar Año (year).',
      );
    });

    it('debe filtrar por año contra los recursos activos de la asignatura', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
        year: 2026,
      };

      const mockResult = [{ id: 'subj-123', name: 'Arquitectura de Software' }];
      mockPrismaService.subject.findMany.mockResolvedValue(mockResult);

      const result = await service.filterCatalog(filters);

      expect(mockPrismaService.subject.findMany).toHaveBeenCalledWith({
        where: {
          career: { universityId: 'univ-123' },
          careerId: 'career-123',
          id: 'subj-123',
          professors: { some: { id: 'prof-123' } },
          resources: {
            some: { active: true, year: 2026 },
          },
        },
        include: {
          career: { include: { university: true } },
          professors: true,
        },
      });
      expect(result).toEqual(mockResult);
    });

    it('debe filtrar por año y tipo exigiendo además el tipo en el recurso', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
        year: 2026,
        type: ResourceType.EXAM,
      };

      mockPrismaService.subject.findMany.mockResolvedValue([]);

      await service.filterCatalog(filters);

      expect(mockPrismaService.subject.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            resources: {
              some: { active: true, year: 2026, type: ResourceType.EXAM },
            },
          }),
        }),
      );
    });

    it('no debe filtrar por recursos cuando no se envía año', async () => {
      mockPrismaService.subject.findMany.mockResolvedValue([]);

      await service.filterCatalog({
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
      });

      const call = mockPrismaService.subject.findMany.mock.calls[0][0];
      expect(call.where).not.toHaveProperty('resources');
    });

    it('no debe devolver el payload de los recursos: la respuesta sigue siendo de asignaturas', async () => {
      mockPrismaService.subject.findMany.mockResolvedValue([]);

      await service.filterCatalog({
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
        year: 2026,
      });

      expect(mockPrismaService.subject.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include: {
            career: { include: { university: true } },
            professors: true,
          },
        }),
      );
    });
  });

  describe('filterCatalog - Consultas válidas a la base de datos', () => {
    it('debe consultar la BD sin filtros si el DTO está vacío', async () => {
      const mockResult = [{ id: 'subj-1', name: 'Estructuras de Datos' }];
      mockPrismaService.subject.findMany.mockResolvedValue(mockResult);

      const result = await service.filterCatalog({});

      expect(prismaService.subject.findMany).toHaveBeenCalledWith({
        where: {},
        include: {
          career: {
            include: {
              university: true,
            },
          },
          professors: true,
        },
      });
      expect(result).toEqual(mockResult);
    });

    it('debe construir la condición where correctamente para una secuencia válida hasta el Nivel 4 (Profesor)', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
      };

      const mockResult = [{ id: 'subj-123', name: 'Arquitectura de Software' }];
      mockPrismaService.subject.findMany.mockResolvedValue(mockResult);

      const result = await service.filterCatalog(filters);

      expect(prismaService.subject.findMany).toHaveBeenCalledWith({
        where: {
          career: { universityId: 'univ-123' },
          careerId: 'career-123',
          id: 'subj-123',
          professors: {
            some: { id: 'prof-123' },
          },
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
      expect(result).toEqual(mockResult);
    });
  });

  // =========================================================================
  // GESTIÓN DEL CATÁLOGO
  // =========================================================================

  /** Error de Prisma que simula una violación de clave única. */
  const duplicatedKey = () =>
    new Prisma.PrismaClientKnownRequestError('duplicate', {
      code: 'P2002',
      clientVersion: '6',
    });

  describe('createUniversity', () => {
    it('debe crear la universidad con active por defecto en true', async () => {
      const created = { id: 'univ-1', name: 'UCT', code: 'UCT', active: true };
      mockPrismaService.university.create.mockResolvedValue(created);

      const result = await service.createUniversity({ name: 'UCT', code: 'UCT' });

      expect(mockPrismaService.university.create).toHaveBeenCalledWith({
        data: { name: 'UCT', code: 'UCT', active: true },
      });
      expect(result).toEqual(created);
    });

    it('debe respetar el active enviado explícitamente', async () => {
      mockPrismaService.university.create.mockResolvedValue({} as never);

      await service.createUniversity({ name: 'UC', code: 'UC', active: false });

      expect(mockPrismaService.university.create).toHaveBeenCalledWith({
        data: { name: 'UC', code: 'UC', active: false },
      });
    });

    it('debe lanzar ConflictException si el código ya existe', async () => {
      mockPrismaService.university.create.mockRejectedValue(duplicatedKey());

      await expect(
        service.createUniversity({ name: 'UCT', code: 'UCT' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('deleteUniversity', () => {
    it('debe eliminar la universidad existente', async () => {
      mockPrismaService.university.findUnique.mockResolvedValue({
        id: 'univ-1',
      } as never);
      mockPrismaService.university.delete.mockResolvedValue({} as never);

      await service.deleteUniversity('univ-1');

      expect(mockPrismaService.university.delete).toHaveBeenCalledWith({
        where: { id: 'univ-1' },
      });
    });

    it('debe lanzar NotFoundException si la universidad no existe', async () => {
      mockPrismaService.university.findUnique.mockResolvedValue(null);

      await expect(service.deleteUniversity('univ-9')).rejects.toThrow(
        new NotFoundException('La universidad con ID univ-9 no existe.'),
      );
      expect(mockPrismaService.university.delete).not.toHaveBeenCalled();
    });
  });

  describe('createCareer', () => {
    it('debe rechazar la carrera si la universidad no existe', async () => {
      mockPrismaService.university.findUnique.mockResolvedValue(null);

      await expect(
        service.createCareer({
          universityId: 'univ-9',
          name: 'Ingeniería',
          code: 'INF',
        }),
      ).rejects.toThrow(NotFoundException);
      expect(mockPrismaService.career.create).not.toHaveBeenCalled();
    });

    it('debe crear la carrera vinculada a su universidad', async () => {
      mockPrismaService.university.findUnique.mockResolvedValue({
        id: 'univ-1',
      } as never);
      const created = { id: 'career-1' };
      mockPrismaService.career.create.mockResolvedValue(created as never);

      const result = await service.createCareer({
        universityId: 'univ-1',
        name: 'Ingeniería',
        code: 'INF',
      });

      expect(mockPrismaService.career.create).toHaveBeenCalledWith({
        data: {
          name: 'Ingeniería',
          code: 'INF',
          universityId: 'univ-1',
          active: true,
        },
      });
      expect(result).toEqual(created);
    });

    it('debe lanzar ConflictException si el código ya existe en la universidad', async () => {
      mockPrismaService.university.findUnique.mockResolvedValue({
        id: 'univ-1',
      } as never);
      mockPrismaService.career.create.mockRejectedValue(duplicatedKey());

      await expect(
        service.createCareer({
          universityId: 'univ-1',
          name: 'Ingeniería',
          code: 'INF',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('deleteCareer', () => {
    it('debe eliminar la carrera existente', async () => {
      mockPrismaService.career.findUnique.mockResolvedValue({
        id: 'career-1',
      } as never);
      mockPrismaService.career.delete.mockResolvedValue({} as never);

      await service.deleteCareer('career-1');

      expect(mockPrismaService.career.delete).toHaveBeenCalledWith({
        where: { id: 'career-1' },
      });
    });

    it('debe lanzar NotFoundException si la carrera no existe', async () => {
      mockPrismaService.career.findUnique.mockResolvedValue(null);

      await expect(service.deleteCareer('career-9')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('createProfessor', () => {
    it('debe crear el profesor sin asignaturas cuando no se indican subjectIds', async () => {
      const created = { id: 'prof-1' };
      mockPrismaService.professor.create.mockResolvedValue(created as never);

      const result = await service.createProfessor({
        name: 'Ana Pérez',
        email: 'ana@uct.cl',
      });

      expect(mockPrismaService.professor.create).toHaveBeenCalledWith({
        data: {
          name: 'Ana Pérez',
          email: 'ana@uct.cl',
          active: true,
          subjects: { connect: [] },
        },
        include: { subjects: true },
      });
      expect(result).toEqual(created);
    });

    it('debe vincular las asignaturas indicadas', async () => {
      mockPrismaService.subject.findMany.mockResolvedValue([
        { id: 'subj-1' },
        { id: 'subj-2' },
      ] as never);
      mockPrismaService.professor.create.mockResolvedValue({} as never);

      await service.createProfessor({
        name: 'Ana Pérez',
        email: 'ana@uct.cl',
        subjectIds: ['subj-1', 'subj-2'],
      });

      expect(mockPrismaService.professor.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            subjects: { connect: [{ id: 'subj-1' }, { id: 'subj-2' }] },
          }),
        }),
      );
    });

    it('debe rechazar y no crear si alguna asignatura no existe', async () => {
      mockPrismaService.subject.findMany.mockResolvedValue([
        { id: 'subj-1' },
      ] as never);

      await expect(
        service.createProfessor({
          name: 'Ana Pérez',
          email: 'ana@uct.cl',
          subjectIds: ['subj-1', 'subj-inexistente'],
        }),
      ).rejects.toThrow(
        new NotFoundException(
          'La(s) asignatura(s) con ID subj-inexistente no existen.',
        ),
      );
      expect(mockPrismaService.professor.create).not.toHaveBeenCalled();
    });

    it('debe lanzar ConflictException si el correo ya está registrado', async () => {
      mockPrismaService.professor.create.mockRejectedValue(duplicatedKey());

      await expect(
        service.createProfessor({ name: 'Ana Pérez', email: 'ana@uct.cl' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('deleteProfessor', () => {
    it('debe eliminar el profesor existente', async () => {
      mockPrismaService.professor.findUnique.mockResolvedValue({
        id: 'prof-1',
      } as never);
      mockPrismaService.professor.delete.mockResolvedValue({} as never);

      await service.deleteProfessor('prof-1');

      expect(mockPrismaService.professor.delete).toHaveBeenCalledWith({
        where: { id: 'prof-1' },
      });
    });

    it('debe lanzar NotFoundException si el profesor no existe', async () => {
      mockPrismaService.professor.findUnique.mockResolvedValue(null);

      await expect(service.deleteProfessor('prof-9')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('createSubject', () => {
    it('debe persistir description y active, que antes se ignoraban', async () => {
      mockPrismaService.career.findUnique.mockResolvedValue({
        id: 'career-1',
      } as never);
      mockPrismaService.subject.create.mockResolvedValue({} as never);

      await service.createSubject({
        careerId: 'career-1',
        name: 'Estructuras de Datos',
        code: 'INF-101',
        semester: 3,
        description: 'Curso sobre árboles y grafos.',
        active: false,
      });

      expect(mockPrismaService.subject.create).toHaveBeenCalledWith({
        data: {
          name: 'Estructuras de Datos',
          code: 'INF-101',
          semester: 3,
          careerId: 'career-1',
          description: 'Curso sobre árboles y grafos.',
          active: false,
        },
      });
    });

    it('debe rechazar si la carrera no existe', async () => {
      mockPrismaService.career.findUnique.mockResolvedValue(null);

      await expect(
        service.createSubject({
          careerId: 'career-9',
          name: 'Estructuras de Datos',
          code: 'INF-101',
          semester: 3,
        }),
      ).rejects.toThrow(NotFoundException);
      expect(mockPrismaService.subject.create).not.toHaveBeenCalled();
    });
  });
});