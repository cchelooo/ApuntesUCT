import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '.prisma/material-client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ListMaterialsQueryDto } from '../dtos/list-materials-query.dto';
import { MaterialPageDto } from '../dtos/material-page.dto';

@Injectable()
export class MaterialsService {
  constructor(private readonly prisma: PrismaService) {}

  async list({ page, pageSize }: ListMaterialsQueryDto): Promise<MaterialPageDto> {
    const skip = (page - 1) * pageSize;
    if (skip > 2147483647) {
      throw new BadRequestException('El desplazamiento de página excede el máximo permitido.');
    }
    const where = { status: 'PUBLISHED' as const };
    // Both queries see the same snapshot even when materials are published concurrently.
    const [materials, total] = await this.prisma.$transaction(
      [
        this.prisma.material.findMany({
          where,
          skip,
          take: pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          select: {
            id: true,
            title: true,
            description: true,
            uploaderId: true,
            academicOfferingId: true,
            universityId: true,
            careerId: true,
            subjectId: true,
            professorId: true,
            materialTypeId: true,
            materialType: { select: { name: true } },
            academicYear: true,
            status: true,
            verified: true,
            createdAt: true,
            updatedAt: true,
          },
        }),
        this.prisma.material.count({ where }),
      ],
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    return {
      items: materials.map((material) => ({
        ...material,
        materialType: material.materialType.name,
        status: 'PUBLISHED',
        createdAt: material.createdAt.toISOString(),
        updatedAt: material.updatedAt.toISOString(),
      })),
      page,
      pageSize,
      total,
    };
  }
}
