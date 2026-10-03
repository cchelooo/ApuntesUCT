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
});
