export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function isInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

export function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === 'string';
}

export function isIsoDateString(value: unknown): value is string {
  return isNonEmptyString(value) && !Number.isNaN(Date.parse(value));
}
