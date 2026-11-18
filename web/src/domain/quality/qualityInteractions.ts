export const REPORT_REASONS = [
  { value: 'incorrect-content', label: 'Contenido erróneo' },
  { value: 'broken-link', label: 'Enlace roto' },
  { value: 'spam', label: 'Spam o contenido inapropiado' },
  { value: 'copyright', label: 'Posible problema de derechos de autor' },
  { value: 'other', label: 'Otro problema' },
] as const;

export type ReportReason = (typeof REPORT_REASONS)[number]['value'];
export type RatingValue = 1 | 2 | 3 | 4 | 5;
export type QualityOperationSource = 'local-demo' | 'api';

export interface QualityOperationReceipt {
  source: QualityOperationSource;
}

export interface FavoriteOperation {
  materialId: string;
  isFavorite: boolean;
  accessToken: string;
}

export interface RatingOperation {
  materialId: string;
  rating: RatingValue;
  accessToken: string;
}

export interface ReportOperation {
  materialId: string;
  reason: ReportReason;
  details?: string;
  accessToken: string;
}

export interface QualityInteractionsAdapter {
  setFavorite(operation: FavoriteOperation): Promise<QualityOperationReceipt>;
  submitRating(operation: RatingOperation): Promise<QualityOperationReceipt>;
  submitReport(operation: ReportOperation): Promise<QualityOperationReceipt>;
}

export function hasValidAccessToken(
  accessToken: string | undefined
): accessToken is string {
  return typeof accessToken === 'string' && accessToken.trim().length > 0;
}

export function getOperationFeedback(
  receipt: QualityOperationReceipt,
  localMessage: string,
  remoteMessage: string
): string {
  return receipt.source === 'local-demo' ? localMessage : remoteMessage;
}
