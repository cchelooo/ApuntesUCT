import type { CatalogNames } from '../../domain/catalog/catalogNames';
import type {
  MaterialDetail,
  MaterialVersion,
} from '../../domain/material/material';
import type {
  MaterialCurrentVersion,
  MaterialDetailResponse,
} from '../../domain/material/materialApi';
import { buildMaterialDownloadUrl } from './materialApi';

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

function mapVersion(raw: MaterialCurrentVersion): MaterialVersion {
  return {
    number: integer(raw.versionNumber) ?? 1,
    uploadedAt: formatDate(raw.createdAt),
    uploadedBy: null,
    fileFormat: FORMAT_BY_MIME[text(raw.mimeType) ?? ''] ?? null,
    fileSizeLabel: formatBytes(raw.fileSize),
  };
}

export function mapMaterialDetail(
  raw: MaterialDetailResponse,
  names?: CatalogNames
): MaterialDetail {
  const subjectId = text(raw.subjectId);
  const professorId = text(raw.professorId);
  const version = raw.currentVersion ?? null;

  return {
    id: String(raw.id),
    title: text(raw.title) ?? UNTITLED,
    description: text(raw.description),
    type: text(raw.materialType),
    year: integer(raw.academicYear),
    subjectName: subjectId ? (names?.subjects[subjectId] ?? null) : null,
    professorName: professorId
      ? (names?.professors[professorId] ?? null)
      : null,
    version: version ? mapVersion(version) : null,
    downloadUrl: version ? buildMaterialDownloadUrl(String(raw.id)) : null,
  };
}
