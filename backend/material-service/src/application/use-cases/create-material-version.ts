import { Prisma } from '.prisma/material-client';
import {
  BadGatewayException,
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ObjectStorage } from '../ports/object-storage.port';
import type { MaterialAuthor, MaterialUpload } from './create-material';

@Injectable()
export class CreateMaterialVersion {
  private readonly logger = new Logger(CreateMaterialVersion.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: ObjectStorage,
  ) {}

  async execute(materialId: string, author: MaterialAuthor, file: MaterialUpload) {
    if (!file?.buffer.length) throw new BadRequestException('Se requiere un archivo no vacío.');
    const checkMaterial = async (db: Prisma.TransactionClient) => {
      const material = await db.material.findUnique({
        where: { id: materialId },
        include: { materialType: true },
      });
      if (!material) throw new NotFoundException('Material no encontrado.');
      if (material.uploaderId !== author.id) {
        throw new ForbiddenException('Solo el autor puede crear una nueva versión del material.');
      }
      if (material.materialType.name === 'LINK') {
        throw new BadRequestException('Los enlaces no admiten versiones de archivo.');
      }
    };
    await checkMaterial(this.prisma);

    let storageKey: string;
    try {
      ({ storageKey } = await this.storage.save(file.buffer, file.mimetype));
    } catch {
      throw new BadGatewayException('No se pudo almacenar el archivo. Intenta nuevamente.');
    }

    try {
      const version = await this.prisma.$transaction(
        async (tx) => {
          // Serializa las cargas del mismo material antes de leer la última versión.
          await tx.$queryRaw`SELECT id FROM materials WHERE id = ${materialId}::uuid FOR UPDATE`;
          await checkMaterial(tx);
          const latest = await tx.materialVersion.findFirst({
            where: { materialId },
            orderBy: { versionNumber: 'desc' },
            select: { versionNumber: true },
          });
          const created = await tx.materialVersion.create({
            data: {
              materialId,
              versionNumber: (latest?.versionNumber ?? 0) + 1,
              storageKey,
              originalFilename: file.originalname,
              mimeType: file.mimetype,
              fileSize: BigInt(file.buffer.length),
              checksum: createHash('sha256').update(file.buffer).digest('hex'),
              createdBy: author.id,
            },
          });
          await tx.material.update({ where: { id: materialId }, data: { updatedAt: new Date() } });
          return created;
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
      );
      return {
        id: version.id,
        materialId: version.materialId,
        versionNumber: version.versionNumber,
        originalFilename: version.originalFilename,
        mimeType: version.mimeType,
        fileSize: version.fileSize.toString(),
        createdBy: version.createdBy,
        createdAt: version.createdAt.toISOString(),
      };
    } catch (error) {
      // Solo limpiar ante rollback confirmado; una desconexión puede ocultar un commit exitoso.
      const rollbackCodes = [
        'P2000',
        'P2002',
        'P2003',
        'P2004',
        'P2011',
        'P2014',
        'P2025',
        'P2034',
      ];
      const rolledBack =
        error instanceof NotFoundException ||
        error instanceof ForbiddenException ||
        error instanceof BadRequestException ||
        (error instanceof Prisma.PrismaClientKnownRequestError &&
          rollbackCodes.includes(error.code));
      if (rolledBack) {
        try {
          const reference = await this.prisma.materialVersion.findFirst({
            where: { storageKey },
            select: { id: true },
          });
          if (!reference) await this.storage.remove(storageKey);
        } catch {
          this.logger.warn(`Limpieza pendiente: ${storageKey}`);
        }
      } else {
        this.logger.warn(
          `Limpieza pendiente por resultado de persistencia incierto: ${storageKey}`,
        );
      }
      throw error;
    }
  }
}
