import { Test, TestingModule } from '@nestjs/testing';
import { CatalogController } from './catalog.controller';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';

describe('CatalogController', () => {
  let controller: CatalogController;
  let service: jest.Mocked<CatalogService>;

  const mockCatalogService = {
    getCatalogTree: jest.fn(),
    filterCatalog: jest.fn(),
    listUniversities: jest.fn(),
    listCareers: jest.fn(),
    listSubjects: jest.fn(),
    listProfessors: jest.fn(),
    createUniversity: jest.fn(),
    deleteUniversity: jest.fn(),
    createCareer: jest.fn(),
    deleteCareer: jest.fn(),
    createProfessor: jest.fn(),
    deleteProfessor: jest.fn(),
    createSubject: jest.fn(),
    deleteSubject: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CatalogController],
      providers: [
        {
          provide: CatalogService,
          useValue: mockCatalogService,
        },
      ],
    }).compile();

    controller = module.get<CatalogController>(CatalogController);
    service = module.get(CatalogService);

    jest.clearAllMocks();
  });

  it('debe estar definido', () => {
    expect(controller).toBeDefined();
  });

  describe('GET /catalog', () => {
    it('debe llamar a catalogService.getCatalogTree y retornar el árbol del catálogo', async () => {
      const mockResult = [
        {
          id: 'univ-1',
          name: 'Universidad Católica de Temuco',
          code: 'UCT',
          active: true,
          careers: [],
        },
      ] as unknown as ReturnType<CatalogService['getCatalogTree']>;

      mockCatalogService.getCatalogTree.mockResolvedValue(mockResult);

      const result = await controller.getCatalog();

      expect(service.getCatalogTree).toHaveBeenCalledTimes(1);
      expect(result).toEqual(mockResult);
    });
  });

  describe('GET /catalog/filter', () => {
    it('debe llamar a catalogService.filterCatalog con los filtros proporcionados', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-1',
        careerId: 'car-1',
      };

      const mockResult = [
        { id: 'subj-1', name: 'Programación' },
      ] as unknown as ReturnType<CatalogService['filterCatalog']>;

      mockCatalogService.filterCatalog.mockResolvedValue(mockResult);

      const result = await controller.filterCatalog(filters);

      expect(service.filterCatalog).toHaveBeenCalledWith(filters);
      expect(result).toEqual(mockResult);
    });
  });

  // =========================================================================
  // LISTADOS PARA LOS SELECTORES ACADÉMICOS
  // =========================================================================

  describe('GET /catalog/universities', () => {
    it('debe delegar en catalogService.listUniversities', async () => {
      const mockResult = [{ id: 'univ-1', name: 'UCT' }];
      mockCatalogService.listUniversities.mockResolvedValue(mockResult);

      const result = await controller.listUniversities();

      expect(service.listUniversities).toHaveBeenCalledTimes(1);
      expect(result).toEqual(mockResult);
    });
  });

  describe('GET /catalog/careers', () => {
    it('debe delegar en catalogService.listCareers con el universityId recibido', async () => {
      const mockResult = [{ id: 'career-1', name: 'Informática' }];
      mockCatalogService.listCareers.mockResolvedValue(mockResult);

      const result = await controller.listCareers({ universityId: 'univ-1' });

      expect(service.listCareers).toHaveBeenCalledWith('univ-1');
      expect(result).toEqual(mockResult);
    });

    it('debe delegar sin filtro cuando no se recibe universityId', async () => {
      mockCatalogService.listCareers.mockResolvedValue([]);

      await controller.listCareers({});

      expect(service.listCareers).toHaveBeenCalledWith(undefined);
    });
  });

  describe('GET /catalog/subjects', () => {
    it('debe delegar en catalogService.listSubjects con el careerId recibido', async () => {
      const mockResult = [{ id: 'subj-1', name: 'Programación' }];
      mockCatalogService.listSubjects.mockResolvedValue(mockResult);

      const result = await controller.listSubjects({ careerId: 'career-1' });

      expect(service.listSubjects).toHaveBeenCalledWith('career-1');
      expect(result).toEqual(mockResult);
    });

    it('debe delegar sin filtro cuando no se recibe careerId', async () => {
      mockCatalogService.listSubjects.mockResolvedValue([]);

      await controller.listSubjects({});

      expect(service.listSubjects).toHaveBeenCalledWith(undefined);
    });
  });

  describe('GET /catalog/professors', () => {
    it('debe delegar en catalogService.listProfessors con el subjectId recibido', async () => {
      const mockResult = [{ id: 'prof-1', name: 'Ana Pérez' }];
      mockCatalogService.listProfessors.mockResolvedValue(mockResult);

      const result = await controller.listProfessors({ subjectId: 'subj-1' });

      expect(service.listProfessors).toHaveBeenCalledWith('subj-1');
      expect(result).toEqual(mockResult);
    });

    it('debe delegar sin filtro cuando no se recibe subjectId', async () => {
      mockCatalogService.listProfessors.mockResolvedValue([]);

      await controller.listProfessors({});

      expect(service.listProfessors).toHaveBeenCalledWith(undefined);
    });
  });

  // =========================================================================
  // GESTIÓN DEL CATÁLOGO
  // =========================================================================

  describe('POST /catalog/universities', () => {
    it('debe delegar la creación en catalogService.createUniversity', async () => {
      const dto = { name: 'UCT', code: 'UCT' };
      const created = { id: 'univ-1', ...dto, active: true };

      mockCatalogService.createUniversity.mockResolvedValue(created);

      const result = await controller.createUniversity(dto);

      expect(service.createUniversity).toHaveBeenCalledWith(dto);
      expect(result).toEqual(created);
    });
  });

  describe('DELETE /catalog/universities/:id', () => {
    it('debe delegar la eliminación en catalogService.deleteUniversity', async () => {
      const deleted = { id: 'univ-1' };

      mockCatalogService.deleteUniversity.mockResolvedValue(deleted);

      const result = await controller.deleteUniversity('univ-1');

      expect(service.deleteUniversity).toHaveBeenCalledWith('univ-1');
      expect(result).toEqual(deleted);
    });
  });

  describe('POST /catalog/careers', () => {
    it('debe delegar la creación en catalogService.createCareer', async () => {
      const dto = { universityId: 'univ-1', name: 'Ingeniería', code: 'INF' };
      const created = { id: 'career-1', ...dto, active: true };

      mockCatalogService.createCareer.mockResolvedValue(created);

      const result = await controller.createCareer(dto);

      expect(service.createCareer).toHaveBeenCalledWith(dto);
      expect(result).toEqual(created);
    });
  });

  describe('DELETE /catalog/careers/:id', () => {
    it('debe delegar la eliminación en catalogService.deleteCareer', async () => {
      mockCatalogService.deleteCareer.mockResolvedValue({ id: 'career-1' });

      const result = await controller.deleteCareer('career-1');

      expect(service.deleteCareer).toHaveBeenCalledWith('career-1');
      expect(result).toEqual({ id: 'career-1' });
    });
  });

  describe('POST /catalog/professors', () => {
    it('debe delegar la creación en catalogService.createProfessor', async () => {
      const dto = { name: 'Ana Pérez', email: 'ana@uct.cl', subjectIds: ['s1'] };
      const created = { id: 'prof-1', ...dto, active: true, subjects: [] };

      mockCatalogService.createProfessor.mockResolvedValue(created);

      const result = await controller.createProfessor(dto);

      expect(service.createProfessor).toHaveBeenCalledWith(dto);
      expect(result).toEqual(created);
    });
  });

  describe('DELETE /catalog/professors/:id', () => {
    it('debe delegar la eliminación en catalogService.deleteProfessor', async () => {
      mockCatalogService.deleteProfessor.mockResolvedValue({ id: 'prof-1' });

      const result = await controller.deleteProfessor('prof-1');

      expect(service.deleteProfessor).toHaveBeenCalledWith('prof-1');
      expect(result).toEqual({ id: 'prof-1' });
    });
  });

  describe('POST /catalog/subjects', () => {
    it('debe delegar la creación en catalogService.createSubject', async () => {
      const dto = {
        careerId: 'career-1',
        name: 'Programación',
        code: 'INF-101',
        semester: 1,
      };
      const created = { id: 'subj-1', ...dto, active: true };

      mockCatalogService.createSubject.mockResolvedValue(created);

      const result = await controller.createSubject(dto);

      expect(service.createSubject).toHaveBeenCalledWith(dto);
      expect(result).toEqual(created);
    });
  });

  describe('DELETE /catalog/subjects/:id', () => {
    it('debe delegar la eliminación en catalogService.deleteSubject', async () => {
      mockCatalogService.deleteSubject.mockResolvedValue({ id: 'subj-1' });

      const result = await controller.deleteSubject('subj-1');

      expect(service.deleteSubject).toHaveBeenCalledWith('subj-1');
      expect(result).toEqual({ id: 'subj-1' });
    });
  });
});
