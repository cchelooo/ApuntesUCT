import type { CatalogNames } from '../../domain/catalog/catalogNames';
import type {
  MaterialDetail,
  MaterialVersion,
} from '../../domain/material/material';
import type { MaterialListItem } from '../../domain/material/materialListItem';
import type { MaterialPage } from '../../domain/material/materialPage';
import { buildMaterialDownloadUrl } from './materialApi';
import type {
  RawMaterial,
  RawMaterialDetail,
  RawMaterialPage,
  RawMaterialVersion,
} from './rawMaterial';

const UNTITLED = 'Material sin título';

const FORMAT_BY_MIME: Record<string, string> = {
  'application/pdf': 'PDF',
  'application/msword': 'DOC',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
    'DOCX',
  'application/vnd.ms-powerpoint': 'PPT',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
    'PPTX',
};

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function integer(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function formatBytes(value: unknown): string | null {
  const bytes = Number(value);
  if (!Number.isFinite(bytes) || bytes <= 0) return null;
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatDate(value: unknown): string | null {
  const iso = text(value);
  if (!iso) return null;
  const date = new Date(iso);
  return Number.isNaN(date.getTime())
    ? null
    : date.toLocaleDateString('es-CL', { dateStyle: 'medium' });
}

export function mapRawMaterial(raw: RawMaterial): MaterialListItem {
  return {
    id: String(raw.id),
    title: text(raw.title) ?? UNTITLED,
    year: integer(raw.academicYear),
    type: text(raw.materialType),
    subjectName: null,
    professorName: null,
    subjectId: text(raw.subjectId),
    professorId: text(raw.professorId),
  };
}

export function mapRawMaterialPage(raw: RawMaterialPage): MaterialPage {
  const pageSize = raw.pageSize > 0 ? raw.pageSize : 1;
  return {
    items: raw.items
      .filter((item) => item && item.id !== undefined && item.id !== null)
      .map(mapRawMaterial),
    page: raw.page,
    pageSize,
    total: raw.total,
    totalPages: Math.max(1, Math.ceil(raw.total / pageSize)),
  };
}

function pickCurrentVersion(
  raw: RawMaterialDetail
): RawMaterialVersion | null {
  if (raw.currentVersion) return raw.currentVersion;
  const versions = raw.versions ?? [];
  if (versions.length === 0) return null;
  return versions.reduce((latest, candidate) =>
    (candidate.versionNumber ?? 0) > (latest.versionNumber ?? 0)
      ? candidate
      : latest
  );
}

function mapRawVersion(raw: RawMaterialVersion): MaterialVersion {
  return {
    number: integer(raw.versionNumber) ?? 1,
    uploadedAt: formatDate(raw.createdAt),
    uploadedBy: null,
    fileFormat: FORMAT_BY_MIME[text(raw.mimeType) ?? ''] ?? null,
    fileSizeLabel: formatBytes(raw.fileSize),
  };
}

export function mapRawMaterialDetail(
  raw: RawMaterialDetail,
  names?: CatalogNames
): MaterialDetail {
  const subjectId = text(raw.subjectId);
  const professorId = text(raw.professorId);
  const version = pickCurrentVersion(raw);

  return {
    id: String(raw.id),
    title: text(raw.title) ?? UNTITLED,
    description: text(raw.description),
    type: text(raw.materialType),
    year: integer(raw.academicYear),
    subjectName: subjectId ? (names?.subjects[subjectId] ?? null) : null,
    professorName: professorId ? (names?.professors[professorId] ?? null) : null,
    version: version ? mapRawVersion(version) : null,
    downloadUrl: version ? buildMaterialDownloadUrl(String(raw.id)) : null,
  };
}
