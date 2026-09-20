import { Test, TestingModule } from '@nestjs/testing';
import { CatalogController } from './catalog.controller';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';

describe('CatalogController', () => {
  let controller: CatalogController;
  let service: jest.Mocked<CatalogService>;

  const mockCatalogService = {
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

  describe('GET /catalog/filter', () => {
    it('debe llamar a catalogService.filterCatalog con los filtros proporcionados', async () => {
      const filters: FilterCatalogDto = {
        universityId: 'univ-1',
        careerId: 'car-1',
      };

      // Se utiliza castear a 'unknown' antes del tipo destino para evitar el 'any' explícito
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
