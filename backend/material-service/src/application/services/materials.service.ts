import { publicExternalLink } from '../security/external-link';
import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Readable } from 'node:stream';
import { Prisma } from '.prisma/material-client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ListMaterialsQueryDto } from '../dtos/list-materials-query.dto';
import { MaterialPageDto } from '../dtos/material-page.dto';
import { MaterialDetailDto } from '../dtos/material-detail.dto';
import {
  PendingMaterialDetailDto,
  PendingMaterialPageDto,
} from '../dtos/pending-material.dto';
import {
  ObjectNotFoundError,
  ObjectStorage,
  ObjectStorageError,
} from '../ports/object-storage.port';

export interface DownloadResult {
  versionId: string;
  stream: Readable;
  mimeType: string;
  filename: string;
  size: number;
}

/** Identidad verificada por el guard de moderación (#460). */
export interface ModerationActor {
  id: string;
  role: string | null;
}

@Injectable()
export class MaterialsService {
  private readonly previewAudit = new Logger('MaterialPreviewAudit');
  private readonly adminAudit = new Logger('MaterialAdminAudit');

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: ObjectStorage,
  ) {}

  async list({ page, pageSize }: ListMaterialsQueryDto): Promise<MaterialPageDto> {
    const skip = (page - 1) * pageSize;
    if (skip > 2147483647) {
      throw new BadRequestException('El desplazamiento de página excede el máximo permitido.');
    }
    const where = { status: 'PUBLISHED' as const };
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

  async detail(materialId: string): Promise<MaterialDetailDto> {
    // Consulta exclusivamente la BD de Material. No necesita Catalog ni MinIO.
    const material = await this.prisma.material.findFirst({
      where: { id: materialId, status: 'PUBLISHED' },
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
        externalLink: true,
        createdAt: true,
        updatedAt: true,
        versions: {
          orderBy: { versionNumber: 'desc' },
          select: {
            id: true,
            versionNumber: true,
            originalFilename: true,
            mimeType: true,
            fileSize: true,
            createdAt: true,
          },
        },
      },
    });
    if (!material) throw new NotFoundException('Material no encontrado.');
    const version = material.versions[0];
    if (!version && material.materialType.name !== 'LINK') {
      throw new NotFoundException('Versión del material no encontrada.');
    }
    // Mapeo explícito: nunca serializa storageKey ni campos internos de Prisma.
    const versions = material.versions.map((item) => ({
      id: item.id,
      versionNumber: item.versionNumber,
      originalFilename: item.originalFilename,
      mimeType: item.mimeType,
      fileSize: item.fileSize.toString(),
      createdAt: item.createdAt.toISOString(),
    }));
    return {
      id: material.id,
      title: material.title,
      description: material.description,
      uploaderId: material.uploaderId,
      academicOfferingId: material.academicOfferingId,
      universityId: material.universityId,
      careerId: material.careerId,
      subjectId: material.subjectId,
      professorId: material.professorId,
      materialTypeId: material.materialTypeId,
      materialType: material.materialType.name,
      academicYear: material.academicYear,
      status: 'PUBLISHED',
      verified: material.verified,
      externalLink: publicExternalLink(material.externalLink),
      createdAt: material.createdAt.toISOString(),
      updatedAt: material.updatedAt.toISOString(),
      currentVersion: versions[0] ?? null,
      versions,
    };
  }

  async download(materialId: string, versionId?: string): Promise<DownloadResult> {
    return this.openFile(materialId, versionId, 'PUBLISHED', false);
  }

  async preview(materialId: string, versionId?: string): Promise<DownloadResult> {
    return this.openFile(materialId, versionId, 'PUBLISHED', true);
  }

  async previewPending(
    materialId: string,
    actor: { id: string; role: string | null },
    versionId?: string,
  ): Promise<DownloadResult> {
    const result = await this.openFile(materialId, versionId, 'PENDING_REVIEW', true);
    this.previewAudit.log({
      event: 'material.pending.preview',
      actorId: actor.id,
      role: actor.role,
      materialId,
      versionId: result.versionId,
      timestamp: new Date().toISOString(),
      outcome: 'stream_opened',
    });
    return result;
  }

  async downloadForReview(materialId: string, versionId: string): Promise<DownloadResult> {
    return this.openFile(materialId, versionId, undefined, false);
  }

  /**
   * Listado privado de pendientes para moderadores/administradores (#460).
   * No modifica las consultas públicas: sólo cambia el estado consultado.
   */
  async listPending(
    { page, pageSize }: ListMaterialsQueryDto,
    actor: ModerationActor,
  ): Promise<PendingMaterialPageDto> {
    const skip = (page - 1) * pageSize;
    if (skip > 2147483647) {
      throw new BadRequestException('El desplazamiento de página excede el máximo permitido.');
    }
    const where = { status: 'PENDING_REVIEW' as const };
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
    this.adminAudit.log({
      event: 'material.pending.list',
      actorId: actor.id,
      role: actor.role,
      page,
      pageSize,
      total,
      timestamp: new Date().toISOString(),
      outcome: 'authorized',
    });
    return {
      items: materials.map((material) => ({
        ...material,
        materialType: material.materialType.name,
        status: 'PENDING_REVIEW',
        createdAt: material.createdAt.toISOString(),
        updatedAt: material.updatedAt.toISOString(),
      })),
      page,
      pageSize,
      total,
    };
  }

  /** Detalle privado de un material pendiente; nunca serializa storageKey. */
  async detailPending(
    materialId: string,
    actor: ModerationActor,
  ): Promise<PendingMaterialDetailDto> {
    const material = await this.prisma.material.findFirst({
      where: { id: materialId, status: 'PENDING_REVIEW' },
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
        externalLink: true,
        createdAt: true,
        updatedAt: true,
        versions: {
          orderBy: { versionNumber: 'desc' },
          select: {
            id: true,
            versionNumber: true,
            originalFilename: true,
            mimeType: true,
            fileSize: true,
            createdAt: true,
          },
        },
      },
    });
    if (!material) throw new NotFoundException('Material no encontrado.');
    const version = material.versions[0];
    if (!version && material.materialType.name !== 'LINK') {
      throw new NotFoundException('Versión del material no encontrada.');
    }
    // Mapeo explícito: nunca serializa storageKey ni campos internos de Prisma.
    const versions = material.versions.map((item) => ({
      id: item.id,
      versionNumber: item.versionNumber,
      originalFilename: item.originalFilename,
      mimeType: item.mimeType,
      fileSize: item.fileSize.toString(),
      createdAt: item.createdAt.toISOString(),
    }));
    this.adminAudit.log({
      event: 'material.pending.detail',
      actorId: actor.id,
      role: actor.role,
      materialId,
      versionId: versions[0]?.id ?? null,
      timestamp: new Date().toISOString(),
      outcome: 'authorized',
    });
    return {
      id: material.id,
      title: material.title,
      description: material.description,
      uploaderId: material.uploaderId,
      academicOfferingId: material.academicOfferingId,
      universityId: material.universityId,
      careerId: material.careerId,
      subjectId: material.subjectId,
      professorId: material.professorId,
      materialTypeId: material.materialTypeId,
      materialType: material.materialType.name,
      academicYear: material.academicYear,
      status: 'PENDING_REVIEW',
      verified: material.verified,
      externalLink: publicExternalLink(material.externalLink),
      createdAt: material.createdAt.toISOString(),
      updatedAt: material.updatedAt.toISOString(),
      currentVersion: versions[0] ?? null,
      versions,
    };
  }

  /** Descarga privada de cualquier tipo de archivo de un material pendiente. */
  async downloadPending(
    materialId: string,
    actor: ModerationActor,
    versionId?: string,
  ): Promise<DownloadResult> {
    const result = await this.openFile(materialId, versionId, 'PENDING_REVIEW', false);
    this.adminAudit.log({
      event: 'material.pending.download',
      actorId: actor.id,
      role: actor.role,
      materialId,
      versionId: result.versionId,
      timestamp: new Date().toISOString(),
      outcome: 'stream_opened',
    });
    return result;
  }

  private async openFile(
    materialId: string,
    versionId: string | undefined,
    status: 'PUBLISHED' | 'PENDING_REVIEW' | undefined,
    pdfOnly: boolean,
  ): Promise<DownloadResult> {
    const material = await this.prisma.material.findFirst({
      where: { id: materialId, status },
      select: { id: true },
    });
    if (!material) {
      throw new NotFoundException('Material no encontrado.');
    }
    const version = versionId
      ? await this.prisma.materialVersion.findFirst({ where: { id: versionId, materialId } })
      : await this.prisma.materialVersion.findFirst({
          where: { materialId },
          orderBy: { versionNumber: 'desc' },
        });
    if (!version) throw new NotFoundException('Versión del material no encontrada.');
    if (pdfOnly && version.mimeType !== 'application/pdf') {
      throw new NotFoundException('Previsualización PDF no disponible.');
    }
    try {
      const stream = await this.storage.get(version.storageKey);
      return {
        versionId: version.id,
        stream,
        mimeType: version.mimeType,
        filename: version.originalFilename,
        size: Number(version.fileSize),
      };
    } catch (error) {
      if (error instanceof ObjectNotFoundError)
        throw new NotFoundException('Archivo no disponible.');
      if (error instanceof ObjectStorageError) {
        throw new ServiceUnavailableException('Almacenamiento de archivos no disponible.');
      }
      throw error;
    }
  }
}
