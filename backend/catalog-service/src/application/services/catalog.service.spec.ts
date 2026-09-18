import { BadRequestException, NotImplementedException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { FilterCatalogDto } from '../dtos/filter-catalog.dto';
import { CatalogService } from './catalog.service';

describe('CatalogService', () => {
  let service: CatalogService;
  let prismaService: jest.Mocked<PrismaService>;

  const mockPrismaService = {
    subject: {
      findMany: jest.fn(),
    },
    university: {
      findMany: jest.fn(),
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
          careers: [
            {
              id: 'career-123',
              name: 'Ingeniería Civil en Informática',
              code: 'ICI',
              active: true,
              subjects: [
                {
                  id: 'subj-123',
                  name: 'Estructura de Datos',
                  code: 'ICI-201',
                  semester: 3,
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
          careers: {
            where: { active: true },
            select: {
              id: true,
              name: true,
              code: true,
              active: true,
              subjects: {
                select: {
                  id: true,
                  name: true,
                  code: true,
                  semester: true,
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

    it('debe lanzar NotImplementedException si se envían los niveles 5 u 6 (year / type) por dependencia pendiente de Resource', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-123',
        careerId: 'career-123',
        subjectId: 'subj-123',
        professorId: 'prof-123',
        year: 2026,
        type: 'Prueba',
      };

      await expect(service.filterCatalog(filters)).rejects.toThrow(
        NotImplementedException,
      );
      await expect(service.filterCatalog(filters)).rejects.toThrow(
        'Los filtros por Año y Tipo requieren el módulo de Recursos (Resource), el cual está pendiente de integración en la base de datos.',
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
});
