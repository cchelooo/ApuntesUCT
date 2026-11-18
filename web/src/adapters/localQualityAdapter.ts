import type {
  FavoriteOperation,
  QualityInteractionsAdapter,
  QualityOperationReceipt,
  RatingOperation,
  ReportOperation,
} from '../domain/quality/qualityInteractions';
import { hasValidAccessToken } from '../domain/quality/qualityInteractions';

const DEMO_RECEIPT: QualityOperationReceipt = { source: 'local-demo' };

function assertAuthenticated(materialId: string, accessToken: string): void {
  if (!materialId.trim()) {
    throw new Error('Se requiere el identificador del material.');
  }
  if (!hasValidAccessToken(accessToken)) {
    throw new Error('Se requiere una sesión autenticada.');
  }
}

export function createLocalQualityAdapter(): QualityInteractionsAdapter {
  return {
    async setFavorite({
      materialId,
      accessToken,
    }: FavoriteOperation): Promise<QualityOperationReceipt> {
      assertAuthenticated(materialId, accessToken);
      return DEMO_RECEIPT;
    },
    async submitRating({
      materialId,
      rating,
      accessToken,
    }: RatingOperation): Promise<QualityOperationReceipt> {
      assertAuthenticated(materialId, accessToken);
      if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        throw new Error('La calificación debe estar entre 1 y 5.');
      }
      return DEMO_RECEIPT;
    },
    async submitReport({
      materialId,
      accessToken,
    }: ReportOperation): Promise<QualityOperationReceipt> {
      assertAuthenticated(materialId, accessToken);
      return DEMO_RECEIPT;
    },
  };
}

export const localQualityAdapter = createLocalQualityAdapter();

export type {
  FavoriteOperation,
  QualityInteractionsAdapter,
  QualityOperationReceipt,
  QualityOperationSource,
  RatingOperation,
  RatingValue,
  ReportOperation,
  ReportReason,
} from '../domain/quality/qualityInteractions';
export { REPORT_REASONS } from '../domain/quality/qualityInteractions';
