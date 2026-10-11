import { Prisma } from '.prisma/material-client';
import { BadGatewayException, BadRequestException, Injectable, Logger } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { ObjectStorage } from '../ports/object-storage.port';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

export interface MaterialAuthor {
  id: string;
  universityId: string | null;
}

export interface CreateMaterialInput {
  title: string;
  description?: string;
  year: string;
  type: string;
  subjectId: string;
  careerId?: string;
  professorId?: string;
  externalLink?: string;
}

export interface MaterialUpload {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
}

@Injectable()
export class CreateMaterial {
  private readonly logger = new Logger(CreateMaterial.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: ObjectStorage,
  ) {}

  async execute(input: CreateMaterialInput, author: MaterialAuthor, file?: MaterialUpload) {
    if (input.type === 'LINK') {
      if (!input.externalLink || file) {
        throw new BadRequestException('LINK requiere externalLink y no admite archivo.');
      }
    } else if (!file) {
      throw new BadRequestException('Este tipo de material requiere un archivo local.');
    }

    const type = await this.prisma.materialType.findFirst({
      where: { name: input.type, active: true },
      select: { id: true },
    });
    if (!type) throw new BadRequestException('Tipo de material inexistente o inactivo.');

    let storageKey: string | undefined;
    if (file) {
      try {
        ({ storageKey } = await this.storage.save(file.buffer, file.mimetype));
      } catch {
        throw new BadGatewayException('No se pudo almacenar el archivo. Intenta nuevamente.');
      }
    }

    // Prisma ejecuta la creación anidada de material y versión en una transacción.
    // Nunca registrar una versión antes de confirmar la escritura del objeto.
    const material = await this.prisma.material
      .create({
        data: {
          title: input.title,
          description: input.description ?? null,
          academicYear: Number(input.year),
          materialTypeId: type.id,
          uploaderId: author.id,
          universityId: author.universityId,
          subjectId: input.subjectId,
          careerId: input.careerId ?? null,
          professorId: input.professorId ?? null,
          externalLink: input.externalLink ?? null,
          status: 'PENDING_REVIEW',
          ...(file && storageKey
            ? {
                versions: {
                  create: {
                    versionNumber: 1,
                    storageKey,
                    originalFilename: file.originalname,
                    mimeType: file.mimetype,
                    fileSize: BigInt(file.buffer.length),
                    checksum: createHash('sha256').update(file.buffer).digest('hex'),
                    createdBy: author.id,
                  },
                },
              }
            : {}),
        },
      })
      .catch(async (error: unknown) => {
        if (storageKey) await this.cleanupFailedUpload(storageKey, error);
        throw error;
      });

    return {
      status: 'success',
      isSimulatedResponse: false,
      message: 'Material registrado exitosamente en estado PENDING_REVIEW.',
      data: {
        id: material.id,
        title: material.title,
        description: material.description,
        year: String(material.academicYear),
        type: input.type,
        status: material.status,
        subjectId: material.subjectId,
        careerId: material.careerId,
        professorId: material.professorId,
        universityId: material.universityId,
        // La descarga se implementará en su caso de uso; nunca publicar la ruta MinIO.
        fileUrl: null,
        fileSize: file?.buffer.length ?? null,
        mimeType: file?.mimetype ?? null,
        externalLink: material.externalLink,
        createdAt: material.createdAt.toISOString(),
      },
    };
  }

  private async cleanupFailedUpload(storageKey: string, error: unknown): Promise<void> {
    // Solo errores que confirman rechazo/rollback. Una consulta sin resultados
    // tras un timeout no demuestra que el commit original haya terminado.
    const rollbackCodes = ['P2000', 'P2002', 'P2003', 'P2004', 'P2011', 'P2014', 'P2025', 'P2034'];
    if (
      !(error instanceof Prisma.PrismaClientKnownRequestError) ||
      !rollbackCodes.includes(error.code)
    ) {
      this.logger.warn(`Limpieza pendiente por resultado de persistencia incierto: ${storageKey}`);
      return;
    }
    try {
      const reference = await this.prisma.materialVersion.findFirst({
        where: { storageKey },
        select: { id: true },
      });
      if (!reference) await this.storage.remove(storageKey);
    } catch {
      // No reemplazar el error original ni exponer detalles del SDK al cliente.
      this.logger.warn(`Limpieza pendiente: no se pudo verificar o eliminar ${storageKey}`);
    }
  }
}
